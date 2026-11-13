using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace Noqi;

public class MainWindow : Window
{
    readonly Store S;
    readonly ContentControl _host = new();
    readonly StackPanel _nav = new() { Spacing = 4 };
    readonly Border _userChip;
    readonly Border _sourceChip;
    Page _page;

    public MainWindow(Store store)
    {
        S = store;
        Title = "Noqi";
        Width = 1280;
        Height = 820;
        MinWidth = 1024;
        MinHeight = 660;
        Background = Th.Bg;
        SystemDecorations = SystemDecorations.None;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;

        _userChip = new Border();
        _sourceChip = new Border();

        Content = BuildShell();
        Opened += async (_, __) => await BootAsync();
        KeyDown += (_, e) =>
        {
            if (e.Key == Key.F11)
            {
                WindowState = WindowState == WindowState.FullScreen ? WindowState.Normal : WindowState.FullScreen;
            }
        };
    }

    Control BuildShell()
    {
        var root = new Grid
        {
            RowDefinitions = new RowDefinitions("40,*"),
            Background = Th.Bg,
        };

        // ── title bar ────────────────────────────────────────
        var bar = new Border
        {
            Background = Th.Bg,
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(0, 0, 0, 1),
        };
        var barGrid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
        var brand = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 9,
            Margin = new Thickness(16, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        brand.Children.Add(Logo(22));
        brand.Children.Add(Th.T("NOQI", 11.5, FontWeight.Bold, Th.Text));
        barGrid.Children.Add(brand);

        var btns = new StackPanel { Orientation = Orientation.Horizontal };
        btns.Children.Add(CaptionButton(Th.IMinimize, () => WindowState = WindowState.Minimized));
        btns.Children.Add(CaptionButton(Th.IMaximize, ToggleMax));
        btns.Children.Add(CaptionButton(Th.IClose, Close, danger: true));
        Grid.SetColumn(btns, 2);
        barGrid.Children.Add(btns);
        bar.Child = barGrid;
        bar.PointerPressed += (_, e) =>
        {
            if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) BeginMoveDrag(e);
        };
        bar.DoubleTapped += (_, __) => ToggleMax();
        root.Children.Add(bar);

        // ── body ─────────────────────────────────────────────
        var body = new Grid { ColumnDefinitions = new ColumnDefinitions("216,*") };
        Grid.SetRow(body, 1);

        var side = new Border
        {
            Background = new SolidColorBrush(Color.Parse("#0A0A0E")),
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(0, 0, 1, 0),
            Padding = new Thickness(14, 18, 14, 16),
        };
        var sideGrid = new Grid { RowDefinitions = new RowDefinitions("Auto,*,Auto") };

        var navHost = new StackPanel { Spacing = 4, Margin = new Thickness(0, 22, 0, 0) };
        navHost.Children.Add(NavItem(Th.IHome, "首页", "home"));
        navHost.Children.Add(NavItem(Th.ILibrary, "片库", "library"));
        navHost.Children.Add(NavItem(Th.ISearch, "搜索", "search"));
        navHost.Children.Add(NavItem(Th.IPerson, "我的", "profile"));
        _nav.Children.Add(navHost);
        sideGrid.Children.Add(_nav);

        var bottom = new StackPanel { Spacing = 8 };
        bottom.Children.Add(new TextBlock
        {
            Text = "片源",
            FontSize = 10,
            Foreground = Th.Faint,
            Margin = new Thickness(4, 0, 0, 2),
        });
        bottom.Children.Add(_sourceChip);
        bottom.Children.Add(_userChip);
        Grid.SetRow(bottom, 2);
        sideGrid.Children.Add(bottom);
        side.Child = sideGrid;
        body.Children.Add(side);

        _host.Background = Th.Bg;
        Grid.SetColumn(_host, 1);
        body.Children.Add(_host);

        root.Children.Add(body);
        return root;
    }

    void ToggleMax()
    {
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    }

    Control CaptionButton(string glyph, Action onClick, bool danger = false)
    {
        var b = new Border
        {
            Width = 46,
            Height = 40,
            Child = Th.Glyph(glyph, 10, Th.Sub),
            Background = Brushes.Transparent,
        };
        b.PointerEntered += (_, __) =>
        {
            b.Background = danger ? new SolidColorBrush(Color.Parse("#C42B1C")) : new SolidColorBrush(Color.Parse("#1A1A22"));
            ((TextBlock)b.Child).Foreground = danger ? Brushes.White : Th.Text;
        };
        b.PointerExited += (_, __) =>
        {
            b.Background = Brushes.Transparent;
            ((TextBlock)b.Child).Foreground = Th.Sub;
        };
        b.PointerPressed += (_, e) =>
        {
            if (e.GetCurrentPoint(b).Properties.IsLeftButtonPressed) onClick();
        };
        return b;
    }

    public Control Logo(double size)
    {
        return new Border
        {
            Width = size,
            Height = size,
            CornerRadius = new CornerRadius(size * 0.3),
            Background = Th.Gold,
            Child = Th.Glyph(Th.IPlay, size * 0.42, Th.Ink),
            VerticalAlignment = VerticalAlignment.Center,
        };
    }

    Control NavItem(string glyph, string label, string key)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 11 };
        var icon = Th.Glyph(glyph, 15, Th.Sub);
        var text = Th.T(label, 13, FontWeight.Medium, Th.Sub);
        row.Children.Add(icon);
        row.Children.Add(text);
        var border = new Border
        {
            Child = row,
            Height = 42,
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(13, 0, 13, 0),
            Background = Brushes.Transparent,
            Tag = key,
        };
        border.PointerPressed += (_, e) =>
        {
            if (e.GetCurrentPoint(border).Properties.IsLeftButtonPressed) _ = Go(key);
        };
        border.PointerEntered += (_, __) =>
        {
            if ((string)border.Tag != CurrentKey) border.Background = new SolidColorBrush(Color.Parse("#12FFFFFF"));
        };
        border.PointerExited += (_, __) =>
        {
            if ((string)border.Tag != CurrentKey) border.Background = Brushes.Transparent;
        };
        return border;
    }

    public string CurrentKey { get; private set; } = "home";

    void PaintNav()
    {
        foreach (var item in EnumerateNav(_nav))
        {
            var key = (string)item.Tag;
            var active = key == CurrentKey;
            item.Background = active ? Th.AccentWash : Brushes.Transparent;
            if (item.Child is StackPanel sp)
            {
                ((TextBlock)sp.Children[0]).Foreground = active ? Th.Accent : Th.Sub;
                ((TextBlock)sp.Children[1]).Foreground = active ? Th.Accent : Th.Sub;
                ((TextBlock)sp.Children[1]).FontWeight = active ? FontWeight.SemiBold : FontWeight.Medium;
            }
        }
    }

    static IEnumerable<Border> EnumerateNav(StackPanel host)
    {
        foreach (var c in host.Children)
        {
            if (c is StackPanel sp)
                foreach (var b in sp.Children)
                    if (b is Border br && br.Tag is string) yield return br;
        }
    }

    public async Task Go(string key, object arg = null)
    {
        CurrentKey = key;
        PaintNav();
        Page page;
        switch (key)
        {
            case "library": page = new LibraryPage(S, this, arg as List<VodClass>); break;
            case "search": page = new SearchPage(S, this); break;
            case "profile": page = new ProfilePage(S, this); break;
            case "detail":
                page = arg is DetailArg da
                    ? new DetailPage(S, this, da.Vod, da.Site)
                    : new DetailPage(S, this, arg as Vod);
                break;
            default: page = new HomePage(S, this); break;
        }
        _page = page;
        _host.Content = page;
        await page.LoadAsync();
        RefreshChips();
    }

    public async Task Reload()
    {
        if (_page != null) await _page.LoadAsync();
    }

    async Task BootAsync()
    {
        _host.Content = new Panel
        {
            Children =
            {
                new StackPanel
                {
                    VerticalAlignment = VerticalAlignment.Center,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Spacing = 18,
                    Children =
                    {
                        new Border
                        {
                            Width = 64, Height = 64,
                            CornerRadius = new CornerRadius(18),
                            Background = Th.Gold,
                            Child = Th.Glyph(Th.IPlay, 26, Th.Ink),
                            HorizontalAlignment = HorizontalAlignment.Center,
                        },
                        Th.T("NOQI", 13, FontWeight.Bold, Th.Sub),
                        Th.Spinner(),
                    },
                },
            },
        };
        try
        {
            await S.BootAsync();
            await Go("home");
        }
        catch (ApiError e)
        {
            ShowBootError(e.Message);
        }
        catch (Exception)
        {
            ShowBootError("无法连接服务器，请检查网络或服务器地址");
        }
    }

    void ShowBootError(string msg)
    {
        _host.Content = new StackPanel
        {
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
            Spacing = 16,
            Children =
            {
                Th.Glyph(Th.IWarning, 26, Th.Faint),
                Th.T(msg, 13, FontWeight.Normal, Th.Sub, wrap: true),
                new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 10,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Children =
                    {
                        Th.Ghost("服务器设置", async () => await OpenSettings()),
                        Th.Btn("重试", async () => await BootAsync()),
                    },
                },
            },
        };
    }

    public async Task OpenSettings()
    {
        var dlg = new SettingsDialog(S);
        await dlg.ShowDialog(this);
        if (dlg.FontChanged) await Go(CurrentKey);
        if (dlg.Saved) await BootAsync();
    }

    public void RefreshChips()
    {
        var src = S.Current;
        var lockGlyph = S.Config != null && S.Config.SiteVip && (src?.IsVip ?? false) && !S.CanPlay(src);
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 7 };
        row.Children.Add(Th.Glyph(Th.ILibrary, 12, Th.Sub));
        row.Children.Add(Th.T(src?.Name ?? "—", 12, FontWeight.Medium, Th.Text, maxLines: 1));
        if (lockGlyph) row.Children.Add(Th.Glyph(Th.ILock, 10, Th.Faint));
        row.Children.Add(Th.Glyph(Th.IDown, 9, Th.Faint));
        _sourceChip.Child = row;
        _sourceChip.Height = 36;
        _sourceChip.CornerRadius = new CornerRadius(9);
        _sourceChip.Background = Th.Surface;
        _sourceChip.BorderBrush = Th.Line;
        _sourceChip.BorderThickness = new Thickness(1);
        _sourceChip.Padding = new Thickness(10, 0, 10, 0);
        _sourceChip.Cursor = new Cursor(StandardCursorType.Hand);
        _sourceChip.PointerPressed -= OnSourceChip;
        _sourceChip.PointerPressed += OnSourceChip;

        var u = S.User;
        var urow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 9 };
        urow.Children.Add(new Border
        {
            Width = 26, Height = 26,
            CornerRadius = new CornerRadius(13),
            Background = u != null && u.VipActive ? Th.Gold : Th.SurfaceHi,
            Child = Th.T(u == null ? "N" : (u.DisplayName.Length > 0 ? u.DisplayName.Substring(0, 1).ToUpper() : "N"), 11,
                FontWeight.Bold, u != null && u.VipActive ? Th.Ink : Th.Sub),
            VerticalAlignment = VerticalAlignment.Center,
        });
        var col = new StackPanel { Spacing = 1, VerticalAlignment = VerticalAlignment.Center };
        col.Children.Add(Th.T(u?.DisplayName ?? "未登录", 11.5, FontWeight.Medium, u == null ? Th.Sub : Th.Text, maxLines: 1));
        col.Children.Add(Th.T(u == null ? "点击登录" : (u.VipActive ? $"会员 · {u.DaysLeft} 天" : "普通用户"), 9.5, FontWeight.Normal,
            u != null && u.VipActive ? Th.Accent : Th.Faint, maxLines: 1));
        urow.Children.Add(col);
        _userChip.Child = urow;
        _userChip.Height = 44;
        _userChip.CornerRadius = new CornerRadius(10);
        _userChip.Background = Th.Surface;
        _userChip.BorderBrush = Th.Line;
        _userChip.BorderThickness = new Thickness(1);
        _userChip.Padding = new Thickness(10, 0, 10, 0);
        _userChip.Cursor = new Cursor(StandardCursorType.Hand);
        _userChip.PointerPressed -= OnUserChip;
        _userChip.PointerPressed += OnUserChip;
    }

    async void OnUserChip(object sender, PointerPressedEventArgs e)
    {
        if (!e.GetCurrentPoint(_userChip).Properties.IsLeftButtonPressed) return;
        if (S.User == null)
        {
            var dlg = new LoginDialog(S);
            await dlg.ShowDialog(this);
            if (dlg.LoggedIn) RefreshChips();
            return;
        }
        await Go("profile");
    }

    void OnSourceChip(object sender, PointerPressedEventArgs e)
    {
        if (!e.GetCurrentPoint(_sourceChip).Properties.IsLeftButtonPressed) return;
        var flyout = new MenuFlyout();
        foreach (var s in S.Sources)
        {
            var item = new MenuItem { Header = s.Name + (s.IsVip ? (S.Config?.SiteVip == true ? "  ·  VIP" : "") : "") };
            var code = s.Code;
            item.Click += async (_, __) =>
            {
                S.SelectSource(code);
                RefreshChips();
                await Go(CurrentKey == "home" ? "home" : CurrentKey);
            };
            flyout.Items.Add(item);
        }
        flyout.ShowAt(_sourceChip);
    }

    public void OpenPlayer(Vod vod, string site, int sourceIndex, int episodeIndex)
    {
        var w = new PlayerWindow(S, vod, site, sourceIndex, episodeIndex);
        w.Show(this);
    }

    public void Toast(string msg)
    {
        var border = new Border
        {
            Background = new SolidColorBrush(Color.Parse("#EE1C1C23")),
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(16, 11, 16, 11),
            Child = Th.T(msg, 12.5, FontWeight.Medium, Th.Text),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(0, 0, 0, 34),
            Opacity = 0,
            IsHitTestVisible = false,
        };
        if (Content is Grid g)
        {
            Grid.SetRowSpan(border, 2);
            g.Children.Add(border);
        }
        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(160) };
        var elapsed = 0;
        timer.Tick += (_, __) =>
        {
            elapsed += 160;
            border.Opacity = elapsed < 220 ? elapsed / 220.0 : (elapsed > 2100 ? Math.Max(0, 1 - (elapsed - 2100) / 300.0) : 1);
            if (elapsed > 2500)
            {
                timer.Stop();
                if (Content is Grid gg) gg.Children.Remove(border);
            }
        };
        timer.Start();
    }
}
