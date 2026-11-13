using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;

namespace Noqi;

public class HomePage : Page
{
    readonly StackPanel _body = new() { Spacing = 0 };

    public HomePage(Store store, MainWindow win) : base(store, win)
    {
        Content = new ScrollViewer
        {
            VerticalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
            Content = new Border { Padding = new Thickness(30, 24, 30, 40), Child = _body },
        };
    }

    public override async Task LoadAsync()
    {
        _body.Children.Clear();
        _body.Children.Add(new Border { Height = 420, Child = Th.Spinner() });
        try
        {
            var code = S.Current?.Code ?? "";
            if (string.IsNullOrEmpty(code))
            {
                _body.Children.Clear();
                _body.Children.Add(ErrorBox("未获取到片源，请检查服务器地址", () => _ = LoadAsync()));
                return;
            }
            var home = await S.Api.SiteHome(code);
            var page = await S.Api.List(code, "", 1);
            var hot = await S.Api.Hot(12);

            _body.Children.Clear();
            var locked = !S.CanPlay(S.Current);

            var hero = hot.FirstOrDefault() ?? (page.Items.FirstOrDefault() is Vod v0 ? HotFrom(v0) : null);
            if (hero != null)
            {
                var heroSite = string.IsNullOrEmpty(hero.SiteCode) ? S.Current : (S.ByCode(hero.SiteCode) ?? S.Current);
                _body.Children.Add(BuildHero(hero, !S.CanPlay(heroSite)));
            }

            if (hot.Count > 1)
            {
                _body.Children.Add(SectionTitle("热播", "TOP " + hot.Count));
                var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 14 };
                foreach (var h in hot.Skip(1).Take(11))
                {
                    var item = h;
                    row.Children.Add(PosterCard(S, item.ToVod(), 134, () => _ = W.Go("detail", new DetailArg(item.ToVod(), item.SiteCode)), locked));
                }
                _body.Children.Add(new ScrollViewer
                {
                    HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
                    VerticalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
                    Content = row,
                });
            }

            var classes = home.Classes.Where(c => c.Id != "0").ToList();
            if (classes.Count > 0)
            {
                _body.Children.Add(SectionTitle("分类", "查看全部", () => _ = W.Go("library", classes)));
                var chips = new WrapPanel { ItemWidth = double.NaN };
                var wrap = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                foreach (var c in classes)
                {
                    var cls = c;
                    wrap.Children.Add(Chip(cls.Name, false, () => _ = W.Go("library", classes)));
                }
                _body.Children.Add(wrap);
            }

            _body.Children.Add(SectionTitle("最新上线", "全部影片", () => _ = W.Go("library", classes)));
            var grid = new WrapPanel { ItemWidth = 172, ItemHeight = 268 };
            foreach (var v in page.Items.Take(18))
            {
                var item = v;
                grid.Children.Add(PosterCard(S, item, 156, () => _ = W.Go("detail", item), locked));
            }
            _body.Children.Add(grid);

            _body.Children.Add(new Border
            {
                Margin = new Thickness(0, 34, 0, 0),
                Child = new TextBlock
                {
                    Text = "NOQI  ·  " + S.Base,
                    FontSize = 9.5,
                    LetterSpacing = 1.2,
                    Foreground = Th.Faint,
                    HorizontalAlignment = HorizontalAlignment.Center,
                },
            });
        }
        catch (ApiError e)
        {
            _body.Children.Clear();
            _body.Children.Add(ErrorBox(e.Message, () => _ = LoadAsync()));
        }
        catch (Exception)
        {
            _body.Children.Clear();
            _body.Children.Add(ErrorBox("加载失败，请检查网络连接", () => _ = LoadAsync()));
        }
    }

    static HotItem HotFrom(Vod v) => new() { Id = v.Id, Name = v.Name, Pic = v.Pic, Plays = 0 };

    Control Chip(string label, bool selected, Action onClick)
    {
        var b = new Border
        {
            Child = Th.T(label, 11.5, selected ? FontWeight.SemiBold : FontWeight.Medium, selected ? Th.Ink : Th.Sub, font: Th.Arabic),
            Background = selected ? Th.Text : Th.Surface,
            BorderBrush = selected ? Brushes.Transparent : Th.Line,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(100),
            Padding = new Thickness(14, 7, 14, 7),
            Margin = new Thickness(0, 0, 8, 8),
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
        };
        b.PointerPressed += (_, __) => onClick();
        return b;
    }

    Control BuildHero(HotItem hero, bool locked)
    {
        var panel = new Panel { Height = 352, ClipToBounds = true };

        panel.Children.Add(new Border { Background = Th.Surface });
        panel.Children.Add(Images.CreateFill(hero.Pic, 0.62));
        panel.Children.Add(new Border
        {
            Background = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0.35, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.Parse("#F207070A"), 0),
                    new GradientStop(Color.Parse("#B307070A"), 0.55),
                    new GradientStop(Color.Parse("#E607070A"), 1),
                },
            },
        });

        var info = new StackPanel
        {
            Spacing = 14,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(30, 0, 30, 30),
            MaxWidth = 620,
            HorizontalAlignment = HorizontalAlignment.Left,
        };

        var tagRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        tagRow.Children.Add(new Border
        {
            Background = new SolidColorBrush(Color.Parse("#66000000")),
            BorderBrush = Th.AccentWash,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(6),
            Padding = new Thickness(8, 3, 8, 3),
            Child = Th.T("热播 · " + hero.Plays, 9.5, FontWeight.SemiBold, Th.Accent),
        });
        if (locked)
        {
            tagRow.Children.Add(new Border
            {
                Background = new SolidColorBrush(Color.Parse("#88000000")),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(8, 3, 8, 3),
                Child = Th.Glyph(Th.ILock, 9, Th.Accent),
            });
        }
        info.Children.Add(tagRow);

        info.Children.Add(Th.T(hero.Name, 26, FontWeight.Bold, Th.Text, wrap: true, maxLines: 2, font: Th.Arabic));

        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        actions.Children.Add(Th.Btn("播放", () => _ = W.Go("detail", new DetailArg(hero.ToVod(), hero.SiteCode)), true, Th.IPlay, 42));
        actions.Children.Add(Th.Ghost("详情", () => _ = W.Go("detail", new DetailArg(hero.ToVod(), hero.SiteCode)), Th.IInfo, 42));
        info.Children.Add(actions);

        panel.Children.Add(info);

        return new Border
        {
            CornerRadius = new CornerRadius(20),
            ClipToBounds = true,
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(1),
            Child = panel,
        };
    }
}

public class LibraryPage : Page
{
    readonly StackPanel _body = new() { Spacing = 0 };
    readonly List<VodClass> _classes;
    string _classId = "";
    int _page = 1;
    int _pageCount = 1;
    readonly WrapPanel _grid = new() { ItemWidth = 172, ItemHeight = 268 };

    public LibraryPage(Store store, MainWindow win, List<VodClass> classes) : base(store, win)
    {
        _classes = classes ?? new List<VodClass>();
        Content = new ScrollViewer
        {
            Content = new Border { Padding = new Thickness(30, 24, 30, 40), Child = _body },
        };
    }

    public override async Task LoadAsync()
    {
        _body.Children.Clear();
        try
        {
            if (_classes.Count == 0)
            {
                var home = await S.Api.SiteHome(S.Current?.Code ?? "");
                _classes.AddRange(home.Classes);
            }
            if (_classId.Length == 0 && _classes.Count > 0) _classId = _classes[0].Id;

            var chips = new WrapPanel();
            foreach (var c in _classes)
            {
                var cls = c;
                chips.Children.Add(ChipButton(cls, cls.Id == _classId, async () =>
                {
                    _classId = cls.Id;
                    await LoadAsync();
                }));
            }
            _body.Children.Add(chips);
            _body.Children.Add(new Border { Height = 6 });

            _page = 1;
            var res = await S.Api.List(S.Current?.Code ?? "", _classId, 1);
            _pageCount = res.PageCount;
            _grid.Children.Clear();
            Fill(res);
            _body.Children.Add(_grid);
            _body.Children.Add(MoreButton());
        }
        catch (ApiError e)
        {
            _body.Children.Clear();
            _body.Children.Add(ErrorBox(e.Message, () => _ = LoadAsync()));
        }
    }

    void Fill(PageResult res)
    {
        var locked = !S.CanPlay(S.Current);
        foreach (var v in res.Items)
        {
            var item = v;
            _grid.Children.Add(PosterCard(S, item, 156, () => _ = W.Go("detail", item), locked));
        }
    }

    Control MoreButton()
    {
        var host = new Border { Margin = new Thickness(0, 20, 0, 0), HorizontalAlignment = HorizontalAlignment.Center };
        if (_page >= _pageCount)
        {
            host.Child = Th.T("—  已加载全部  —", 10, FontWeight.Normal, Th.Faint);
            return host;
        }
        host.Child = Th.Ghost("加载更多", async () =>
        {
            host.Child = Th.Spinner();
            try
            {
                var next = await S.Api.List(S.Current?.Code ?? "", _classId, ++_page);
                Fill(next);
                _page = next.Page;
                _pageCount = next.PageCount;
                host.Child = _page >= _pageCount
                    ? Th.T("—  已加载全部  —", 10, FontWeight.Normal, Th.Faint)
                    : Th.Ghost("加载更多", () => { });
            }
            catch (ApiError e)
            {
                host.Child = Th.T(e.Message, 11, FontWeight.Normal, Th.Danger);
            }
        });
        return host;
    }

    Control ChipButton(VodClass cls, bool selected, Func<Task> onClick)
    {
        var b = new Border
        {
            Child = Th.T(cls.Name, 11.5, selected ? FontWeight.SemiBold : FontWeight.Medium, selected ? Th.Ink : Th.Sub, font: Th.Arabic),
            Background = selected ? Th.Text : Th.Surface,
            BorderBrush = selected ? Brushes.Transparent : Th.Line,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(100),
            Padding = new Thickness(14, 7, 14, 7),
            Margin = new Thickness(0, 0, 8, 8),
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
        };
        b.PointerPressed += (_, __) => _ = onClick();
        return b;
    }
}

public class SearchPage : Page
{
    readonly StackPanel _body = new() { Spacing = 0 };
    readonly TextBox _input = new();
    readonly WrapPanel _grid = new() { ItemWidth = 172, ItemHeight = 268 };
    readonly StackPanel _resultHost = new() { Spacing = 12 };

    public SearchPage(Store store, MainWindow win) : base(store, win)
    {
        _input.Watermark = "搜索影片 / ئىزدەش";
        _input.Height = 42;
        _input.FontSize = 13;
        _input.CornerRadius = new CornerRadius(11);
        _input.Background = Th.Surface;
        _input.Foreground = Th.Text;
        _input.BorderBrush = Th.Line;
        _input.KeyDown += (_, e) =>
        {
            if (e.Key == Avalonia.Input.Key.Enter) _ = DoSearch();
        };

        var bar = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        bar.Children.Add(_input);
        var go = Th.Btn("搜索", () => _ = DoSearch(), true, Th.ISearch, 42);
        go.Margin = new Thickness(10, 0, 0, 0);
        Grid.SetColumn(go, 1);
        bar.Children.Add(go);

        _body.Children.Add(bar);
        _body.Children.Add(new Border { Height = 18 });
        _body.Children.Add(_resultHost);

        Content = new ScrollViewer
        {
            Content = new Border { Padding = new Thickness(30, 24, 30, 40), Child = _body },
        };
    }

    public override Task LoadAsync()
    {
        if (_resultHost.Children.Count == 0)
        {
            _resultHost.Children.Add(new StackPanel
            {
                Spacing = 6,
                Children =
                {
                    Th.T("输入关键词开始搜索", 13, FontWeight.Medium, Th.Sub),
                    Th.T("支持维吾尔语、中文与影片编号", 11, FontWeight.Normal, Th.Faint),
                },
            });
        }
        return Task.CompletedTask;
    }

    async Task DoSearch()
    {
        var wd = _input.Text?.Trim() ?? "";
        if (wd.Length == 0) return;
        _resultHost.Children.Clear();
        _resultHost.Children.Add(new Border { Height = 180, Child = Th.Spinner() });
        try
        {
            var res = await S.Api.Search(S.Current?.Code ?? "", wd, 1);
            _resultHost.Children.Clear();
            if (res.Items.Count == 0)
            {
                _resultHost.Children.Add(new StackPanel
                {
                    Spacing = 6,
                    Children =
                    {
                        Th.T("没有找到结果", 13, FontWeight.Medium, Th.Sub),
                        Th.T("换个关键词或切换片源再试", 11, FontWeight.Normal, Th.Faint),
                    },
                });
                return;
            }
            _resultHost.Children.Add(Th.T($"共 {res.Items.Count} 个结果", 11, FontWeight.Normal, Th.Faint));
            _grid.Children.Clear();
            var locked = !S.CanPlay(S.Current);
            foreach (var v in res.Items)
            {
                var item = v;
                _grid.Children.Add(PosterCard(S, item, 156, () => _ = W.Go("detail", item), locked));
            }
            _resultHost.Children.Add(_grid);
        }
        catch (ApiError e)
        {
            _resultHost.Children.Clear();
            _resultHost.Children.Add(ErrorBox(e.Message, () => _ = DoSearch()));
        }
    }
}
