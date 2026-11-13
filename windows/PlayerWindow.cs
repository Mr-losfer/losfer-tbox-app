using System;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using LibVLCSharp.Shared;
using LibVLCSharp.Avalonia;

namespace Noqi;

public class PlayerWindow : Window
{
    readonly Store S;
    readonly Vod V;
    readonly string Site;
    readonly int Src;
    int _ep;

    LibVLC _libvlc;
    MediaPlayer _mp;
    Media _media;
    VideoView _view;
    DispatcherTimer _timer;
    DispatcherTimer _hideTimer;

    readonly Panel _stage = new();
    readonly Panel _overlay = new();
    readonly Slider _seek = new();
    readonly TextBlock _time = Th.T("00:00 / 00:00", 10.5, FontWeight.Normal, new SolidColorBrush(Color.Parse("#CCFFFFFF")));
    readonly TextBlock _epLabel = Th.T("", 10.5, FontWeight.Normal, new SolidColorBrush(Color.Parse("#99FFFFFF")));
    readonly TextBlock _playGlyph;
    readonly TextBlock _status = Th.T("", 12, FontWeight.Normal, new SolidColorBrush(Color.Parse("#CCFFFFFF")), wrap: true);
    bool _dragging;
    bool _closing;

    public PlayerWindow(Store store, Vod vod, string site, int sourceIndex, int episodeIndex)
    {
        S = store;
        V = vod;
        Site = site;
        Src = Math.Max(0, Math.Min(sourceIndex, Math.Max(0, vod.Sources.Count - 1)));
        _ep = episodeIndex;

        Width = 1160;
        Height = 700;
        MinWidth = 720;
        MinHeight = 420;
        Background = Brushes.Black;
        SystemDecorations = SystemDecorations.None;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Title = vod.Name;

        _playGlyph = Th.Glyph(Th.IPause, 18, Brushes.White);

        Content = BuildUi();

        Opened += async (_, __) =>
        {
            await InitAsync();
        };
        KeyDown += OnKey;
        Closed += (_, __) => Cleanup();
    }

    Control BuildUi()
    {
        var root = new Grid();

        _stage.Background = Brushes.Black;
        root.Children.Add(_stage);

        // overlay chrome
        var topBar = new Border
        {
            Background = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.Parse("#B3000000"), 0),
                    new GradientStop(Color.Parse("#00000000"), 1),
                },
            },
            Padding = new Thickness(16, 12, 16, 26),
            VerticalAlignment = VerticalAlignment.Top,
        };
        var topRow = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
        var back = new Border
        {
            Child = Th.Glyph(Th.IBack, 12, Brushes.White),
            Width = 34,
            Height = 30,
            CornerRadius = new CornerRadius(8),
            Background = new SolidColorBrush(Color.Parse("#40FFFFFF")),
            Cursor = new Cursor(StandardCursorType.Hand),
        };
        back.PointerPressed += (_, __) => Close();
        topRow.Children.Add(back);

        var titleCol = new StackPanel
        {
            Spacing = 2,
            Margin = new Thickness(14, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            Children =
            {
                Th.T(V.Name, 14, FontWeight.SemiBold, Brushes.White, maxLines: 1, font: Th.Arabic),
                _epLabel,
            },
        };
        Grid.SetColumn(titleCol, 1);
        topRow.Children.Add(titleCol);

        var tools = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        if (V.Sources.Count > Src && V.Sources[Src].Episodes.Count > 1)
        {
            var epBtn = Chip("选集", Th.IList);
            epBtn.PointerPressed += (_, __) => ShowEpisodes();
            tools.Children.Add(epBtn);
        }
        var fs = Chip("全屏 F", Th.IFullscreen);
        fs.PointerPressed += (_, __) => ToggleFullscreen();
        tools.Children.Add(fs);
        Grid.SetColumn(tools, 2);
        topRow.Children.Add(tools);
        topBar.Child = topRow;

        // bottom bar
        var bottomBar = new Border
        {
            Background = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.Parse("#00000000"), 0),
                    new GradientStop(Color.Parse("#CC000000"), 1),
                },
            },
            Padding = new Thickness(18, 30, 18, 14),
            VerticalAlignment = VerticalAlignment.Bottom,
        };
        var bottom = new StackPanel { Spacing = 8 };
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        var playBtn = new Border
        {
            Width = 38,
            Height = 38,
            CornerRadius = new CornerRadius(10),
            Background = Th.Gold,
            Child = _playGlyph,
            Cursor = new Cursor(StandardCursorType.Hand),
        };
        playBtn.PointerPressed += (_, __) => TogglePlay();
        controls.Children.Add(playBtn);
        controls.Children.Add(IconBtn(Th.IFullscreen, () => SeekBy(-10), rotate: 180));
        controls.Children.Add(IconBtn(Th.IFullscreen, () => SeekBy(10)));
        controls.Children.Add(Th.T("10s", 9, FontWeight.Normal, new SolidColorBrush(Color.Parse("#66FFFFFF"))));

        _seek.Minimum = 0;
        _seek.Maximum = 100;
        _seek.Width = 640;
        _seek.Height = 26;
        _seek.Background = new SolidColorBrush(Color.Parse("#33FFFFFF"));
        _seek.Foreground = Th.Accent;
        _seek.Margin = new Thickness(10, 0, 10, 0);
        _seek.AddHandler(PointerPressedEvent, (_, __) => _dragging = true, RoutingStrategies.Tunnel);
        _seek.AddHandler(PointerReleasedEvent, (_, __) =>
        {
            if (_mp != null && _mp.Length > 0) _mp.Time = (long)_seek.Value;
            _dragging = false;
        }, RoutingStrategies.Tunnel);
        controls.Children.Add(_seek);
        controls.Children.Add(_time);
        bottom.Children.Add(controls);
        bottom.Children.Add(_status);
        bottomBar.Child = bottom;

        _overlay.Children.Add(topBar);
        _overlay.Children.Add(bottomBar);
        _overlay.Background = Brushes.Transparent;
        PointerMoved += (_, __) => ShowChrome();
        root.Children.Add(_overlay);

        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(400) };
        _timer.Tick += (_, __) => Tick();
        _timer.Start();

        _hideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3.2) };
        _hideTimer.Tick += (_, __) =>
        {
            _hideTimer.Stop();
            if (!_seek.IsPointerOver)
            {
                _overlay.Opacity = 0;
                _overlay.IsHitTestVisible = false;
            }
            Cursor = new Cursor(StandardCursorType.None);
        };

        return root;
    }

    Control Chip(string label, string glyph)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        row.Children.Add(Th.Glyph(glyph, 11, Brushes.White));
        row.Children.Add(Th.T(label, 10.5, FontWeight.Medium, Brushes.White));
        return new Border
        {
            Child = row,
            Height = 30,
            Padding = new Thickness(10, 0, 10, 0),
            CornerRadius = new CornerRadius(8),
            Background = new SolidColorBrush(Color.Parse("#33FFFFFF")),
            Cursor = new Cursor(StandardCursorType.Hand),
            VerticalAlignment = VerticalAlignment.Center,
        };
    }

    Control IconBtn(string glyph, Action onClick, double rotate = 0)
    {
        var g = Th.Glyph(glyph, 15, Brushes.White);
        if (rotate != 0) g.RenderTransform = new RotateTransform(rotate);
        var b = new Border
        {
            Child = g,
            Width = 32,
            Height = 32,
            CornerRadius = new CornerRadius(8),
            Cursor = new Cursor(StandardCursorType.Hand),
        };
        b.PointerPressed += (_, __) => onClick();
        b.PointerEntered += (_, __) => b.Background = new SolidColorBrush(Color.Parse("#33FFFFFF"));
        b.PointerExited += (_, __) => b.Background = Brushes.Transparent;
        return b;
    }

    void ShowChrome()
    {
        _overlay.Opacity = 1;
        _overlay.IsHitTestVisible = true;
        Cursor = new Cursor(StandardCursorType.Arrow);
        _hideTimer.Stop();
        _hideTimer.Start();
    }

    async Task InitAsync()
    {
        ShowChrome();
        try
        {
            Core.Initialize();
            _libvlc = new LibVLC("--no-video-title-show", "--quiet", "--avcodec-hw=any");
            _mp = new MediaPlayer(_libvlc) { Volume = 85 };
            _mp.EndReached += (_, __) =>
            {
                if (_closing) return;
                Dispatcher.UIThread.Post(() => _ = Next());
            };
            _mp.EncounteredError += (_, __) =>
            {
                Dispatcher.UIThread.Post(() => _status.Text = "播放中断：请切换片源或重试");
            };
            _view = new VideoView { MediaPlayer = _mp };
            _stage.Children.Add(_view);
            await PlayEp(_ep);
        }
        catch (Exception ex)
        {
            _status.Text = "播放器初始化失败：" + ex.Message;
            var box = new Border
            {
                Background = new SolidColorBrush(Color.Parse("#CC000000")),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(22),
                MaxWidth = 520,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Child = new StackPanel
                {
                    Spacing = 10,
                    Children =
                    {
                        Th.Glyph(Th.IWarning, 22, Th.Faint),
                        Th.T("播放器初始化失败", 14, FontWeight.SemiBold, Brushes.White),
                        Th.T("请确认 libvlc 目录随程序一同分发（VideoLAN.LibVLC.Windows）", 11,
                            FontWeight.Normal, new SolidColorBrush(Color.Parse("#BBFFFFFF")), wrap: true),
                        Th.T(ex.Message, 9.5, FontWeight.Normal, new SolidColorBrush(Color.Parse("#88FFFFFF")), wrap: true),
                    },
                },
            };
            _stage.Children.Add(box);
        }
    }

    async Task PlayEp(int idx)
    {
        if (_mp == null) return;
        if (V.Sources.Count == 0) return;
        var eps = V.Sources[Src].Episodes;
        if (eps.Count == 0) return;
        _ep = Math.Max(0, Math.Min(idx, eps.Count - 1));
        var ep = eps[_ep];
        _epLabel.Text = ep.Label;
        _status.Text = "正在解析播放地址…";
        try
        {
            var info = await S.Api.Play(Site, ep.Play, ep.Q, S.User?.PlayToken);
            var media = new Media(_libvlc, new Uri(info.Url));
            if (info.Headers.TryGetValue("User-Agent", out var ua)) media.AddOption(":http-user-agent=" + ua);
            if (info.Headers.TryGetValue("Referer", out var rf)) media.AddOption(":http-referrer=" + rf);
            if (info.Headers.TryGetValue("Referer", out var rf2)) media.AddOption(":http-referrer=" + rf2);
            _mp.Play(media);
            _status.Text = "";
            _media?.Dispose();
            _media = media;
        }
        catch (ApiError e)
        {
            _status.Text = e.Message;
        }
        catch (Exception)
        {
            _status.Text = "播放失败，请稍后重试";
        }
    }

    void Tick()
    {
        if (_mp == null) return;
        var len = _mp.Length;
        var t = _mp.Time;
        if (len > 0)
        {
            if (!_dragging)
            {
                _seek.Maximum = len;
                _seek.Value = Math.Min(t, len);
            }
            _time.Text = $"{Fmt(t)} / {Fmt(len)}";
        }
        var playing = _mp.IsPlaying;
        _playGlyph.Text = playing ? Th.IPause : Th.IPlay;
        if (_status.Text == "正在解析播放地址…" && playing) _status.Text = "";
    }

    static string Fmt(long ms)
    {
        var d = TimeSpan.FromMilliseconds(Math.Max(0, ms));
        return d.TotalHours >= 1 ? d.ToString(@"h\:mm\:ss") : d.ToString(@"mm\:ss");
    }

    void TogglePlay()
    {
        if (_mp == null) return;
        if (_mp.IsPlaying) _mp.Pause();
        else _mp.Play();
    }

    void SeekBy(int seconds)
    {
        if (_mp == null) return;
        var target = _mp.Time + seconds * 1000L;
        if (target < 0) target = 0;
        if (_mp.Length > 0 && target > _mp.Length - 500) target = _mp.Length - 500;
        _mp.Time = target;
    }

    async Task Next()
    {
        if (V.Sources.Count == 0) return;
        var eps = V.Sources[Src].Episodes;
        if (_ep + 1 >= eps.Count) return;
        await PlayEp(_ep + 1);
    }

    void ShowEpisodes()
    {
        var eps = V.Sources[Src].Episodes;
        var flyout = new MenuFlyout();
        for (var i = 0; i < eps.Count; i++)
        {
            var idx = i;
            var item = new MenuItem { Header = eps[i].Label };
            item.Click += async (_, __) => await PlayEp(idx);
            flyout.Items.Add(item);
        }
        flyout.ShowAt((Control)_overlay.Children[0]);
    }

    void ToggleFullscreen()
    {
        WindowState = WindowState == WindowState.FullScreen ? WindowState.Normal : WindowState.FullScreen;
    }

    void OnKey(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Escape:
                if (WindowState == WindowState.FullScreen) WindowState = WindowState.Normal;
                else Close();
                break;
            case Key.Space:
                TogglePlay();
                break;
            case Key.Left:
                SeekBy(-10);
                break;
            case Key.Right:
                SeekBy(10);
                break;
            case Key.F:
            case Key.F11:
                ToggleFullscreen();
                break;
            case Key.Up:
                if (_mp != null) _mp.Volume = Math.Min(100, _mp.Volume + 5);
                break;
            case Key.Down:
                if (_mp != null) _mp.Volume = Math.Max(0, _mp.Volume - 5);
                break;
        }
        ShowChrome();
        e.Handled = true;
    }

    void Cleanup()
    {
        _closing = true;
        _timer?.Stop();
        _hideTimer?.Stop();
        try
        {
            _mp?.Stop();
            _media?.Dispose();
            _mp?.Dispose();
            _libvlc?.Dispose();
        }
        catch { }
    }
}
