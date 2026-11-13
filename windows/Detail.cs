using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;

namespace Noqi;

public record DetailArg(Vod Vod, string Site);

public class DetailPage : Page
{
    readonly StackPanel _body = new() { Spacing = 0 };
    readonly Vod _seed;
    readonly string _site;
    int _srcIndex;

    public DetailPage(Store store, MainWindow win, Vod seed, string site = null) : base(store, win)
    {
        _seed = seed;
        _site = string.IsNullOrEmpty(site) ? (store.Current?.Code ?? "") : site;
        Content = new ScrollViewer
        {
            Content = new Border { Padding = new Thickness(30, 18, 30, 40), Child = _body },
        };
    }

    public override async Task LoadAsync()
    {
        _body.Children.Clear();
        _body.Children.Add(new Border { Height = 380, Child = Th.Spinner() });
        try
        {
            var vod = await S.Api.Detail(_site, _seed.Id) ?? _seed;
            Render(vod);
        }
        catch (ApiError e)
        {
            _body.Children.Clear();
            _body.Children.Add(BackRow());
            _body.Children.Add(ErrorBox(e.Message, () => _ = LoadAsync()));
        }
    }

    Control BackRow()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Thickness(0, 0, 0, 16) };
        var back = new Border
        {
            Child = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 7,
                Children = { Th.Glyph(Th.IBack, 12, Th.Sub), Th.T("返回", 12, FontWeight.Medium, Th.Sub) },
            },
            Padding = new Thickness(10, 6, 12, 6),
            CornerRadius = new CornerRadius(9),
            Background = Th.Surface,
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
        };
        back.PointerPressed += (_, __) => _ = W.Go("home");
        row.Children.Add(back);
        return row;
    }

    void Render(Vod vod)
    {
        _body.Children.Clear();
        _body.Children.Add(BackRow());

        var locked = !S.CanPlay(S.ByCode(_site) ?? S.Current);
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("250,*") };

        // poster
        row.Children.Add(new Border
        {
            Width = 250,
            Height = 362,
            CornerRadius = new CornerRadius(16),
            ClipToBounds = true,
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(1),
            VerticalAlignment = VerticalAlignment.Top,
            Child = Images.Create(vod.Pic, 250, 362),
        });

        var info = new StackPanel { Margin = new Thickness(26, 4, 0, 0), Spacing = 14 };

        var tagRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var score = double.TryParse(vod.Score.Split(' ')[0], out var sc) ? sc : 0;
        if (score > 0)
        {
            tagRow.Children.Add(new Border
            {
                Background = Th.AccentWash,
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(8, 3, 8, 3),
                Child = new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 4,
                    Children = { Th.Glyph(Th.IStar, 10, Th.Accent), Th.T(score.ToString("0.0"), 10.5, FontWeight.Bold, Th.Accent) },
                },
            });
        }
        if (locked) tagRow.Children.Add(Th.Pill("会员专享", Th.Gold, Th.Ink, 9.5));
        else if (S.Config?.SiteVip == true && S.Current?.IsVip == false) tagRow.Children.Add(Th.Pill("免费片源", new SolidColorBrush(Color.Parse("#1F4CD493")),
            new SolidColorBrush(Color.Parse("#4CD493")), 9.5));
        if (tagRow.Children.Count > 0) info.Children.Add(tagRow);

        info.Children.Add(Th.T(vod.Name, 27, FontWeight.Bold, Th.Text, wrap: true, maxLines: 2, font: Th.Arabic));

        var meta = MetaJoin(vod.Year, vod.Area, vod.TypeName);
        if (meta.Length > 0) info.Children.Add(Th.T(meta, 12, FontWeight.Normal, Th.Sub, font: Th.Arabic));

        if (!string.IsNullOrWhiteSpace(vod.Remarks))
            info.Children.Add(Th.T(vod.Remarks, 11.5, FontWeight.Normal, Th.Faint, font: Th.Arabic));

        var actions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, Margin = new Thickness(0, 6, 0, 0) };
        if (vod.HasEpisodes)
        {
            actions.Children.Add(Th.Btn("播放", () => Play(vod, 0), true, Th.IPlay, 44));
            actions.Children.Add(Th.Ghost("从第 1 集开始", () => Play(vod, 0), Th.IList, 44));
        }
        else
        {
            actions.Children.Add(Th.Ghost("暂无播放源", () => { }, Th.IWarning, 44));
        }
        info.Children.Add(actions);

        if (locked)
        {
            info.Children.Add(new Border
            {
                Background = Th.AccentWash,
                BorderBrush = Th.Accent,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(14, 11, 14, 11),
                Child = new StackPanel
                {
                    Spacing = 3,
                    Children =
                    {
                        Th.T("该片源仅限会员", 12, FontWeight.SemiBold, Th.Accent),
                        Th.T("切换到免费片源，或开通会员后观看", 10.5, FontWeight.Normal, Th.Sub),
                    },
                },
            });
        }

        if (vod.Sources.Count > 1)
        {
            var srcRow = new WrapPanel();
            for (var i = 0; i < vod.Sources.Count; i++)
            {
                var idx = i;
                var selected = idx == _srcIndex;
                var chip = new Border
                {
                    Child = Th.T(vod.Sources[idx].Name, 11, selected ? FontWeight.SemiBold : FontWeight.Medium,
                        selected ? Th.Ink : Th.Sub, font: Th.Arabic),
                    Background = selected ? Th.Text : Th.Surface,
                    BorderBrush = selected ? Brushes.Transparent : Th.Line,
                    BorderThickness = new Thickness(1),
                    CornerRadius = new CornerRadius(100),
                    Padding = new Thickness(13, 6, 13, 6),
                    Margin = new Thickness(0, 0, 8, 8),
                    Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
                };
                chip.PointerPressed += (_, __) =>
                {
                    _srcIndex = idx;
                    Render(vod);
                };
                srcRow.Children.Add(chip);
            }
            info.Children.Add(new StackPanel
            {
                Spacing = 7,
                Children = { Th.T("片源", 11.5, FontWeight.SemiBold, Th.Sub), srcRow },
            });
        }

        if (!string.IsNullOrWhiteSpace(vod.Content))
        {
            var syn = new StackPanel { Spacing = 7 };
            syn.Children.Add(Th.T("剧情简介", 12, FontWeight.SemiBold, Th.Sub));
            syn.Children.Add(Th.T(vod.Content.Trim(), 12.5, FontWeight.Normal, Th.Sub, wrap: true, font: Th.Arabic));
            info.Children.Add(syn);
        }

        Grid.SetColumn(info, 1);
        row.Children.Add(info);
        _body.Children.Add(row);

        var eps = vod.Sources.Count > _srcIndex ? vod.Sources[_srcIndex].Episodes : new List<Episode>();
        if (eps.Count > 1)
        {
            _body.Children.Add(SectionTitle($"剧集  ·  {eps.Count}"));
            var wrap = new WrapPanel { ItemWidth = 104, ItemHeight = 46 };
            for (var i = 0; i < eps.Count; i++)
            {
                var idx = i;
                var b = new Border
                {
                    Background = Th.Surface,
                    BorderBrush = Th.Line,
                    BorderThickness = new Thickness(1),
                    CornerRadius = new CornerRadius(9),
                    Margin = new Thickness(0, 0, 8, 8),
                    VerticalAlignment = VerticalAlignment.Center,
                    Height = 38,
                    Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
                    Child = Th.T(eps[idx].Label, 11, FontWeight.Medium, Th.Sub, font: Th.Arabic, maxLines: 1),
                };
                b.PointerEntered += (_, __) => { b.Background = Th.AccentWash; b.BorderBrush = Th.Accent; };
                b.PointerExited += (_, __) => { b.Background = Th.Surface; b.BorderBrush = Th.Line; };
                b.PointerPressed += (_, e) =>
                {
                    if (e.GetCurrentPoint(b).Properties.IsLeftButtonPressed) Play(vod, idx);
                };
                wrap.Children.Add(b);
            }
            _body.Children.Add(wrap);
        }

        _ = LoadRelated(vod);
    }

    /// <summary>用影片类型去同类目里捞一批，补足详情页底部（失败静默）</summary>
    async Task LoadRelated(Vod vod)
    {
        if (string.IsNullOrWhiteSpace(vod.TypeName)) return;
        try
        {
            var (classes, _) = await S.Api.SiteHome(_site);
            var match = classes.FirstOrDefault(c => c.Name == vod.TypeName)
                        ?? classes.FirstOrDefault(c => c.Id != "0" && !string.IsNullOrEmpty(c.Id));
            if (match == null) return;

            var page = await S.Api.List(_site, match.Id, 1);
            var items = page.Items.Where(v => v.Id != vod.Id).Take(12).ToList();
            if (items.Count == 0) return;

            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 14 };
            foreach (var v in items)
            {
                var item = v;
                row.Children.Add(PosterCard(S, item, 134, () => _ = W.Go("detail", new DetailArg(item, _site)),
                    !S.CanPlay(S.ByCode(_site) ?? S.Current)));
            }
            _body.Children.Add(SectionTitle("相关推荐", $"{items.Count} 部"));
            _body.Children.Add(new ScrollViewer
            {
                HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled,
                Content = row,
            });
        }
        catch
        {
            // 推荐是增强内容，失败不影响主流程
        }
    }

    void Play(Vod vod, int epIndex)
    {
        if (!S.CanPlay(S.ByCode(_site) ?? S.Current))
        {
            W.Toast("该片源仅限会员：请切换免费片源或开通会员");
            return;
        }
        if (!vod.HasEpisodes) return;
        W.OpenPlayer(vod, _site, _srcIndex, epIndex);
    }
}

public class ProfilePage : Page
{
    readonly StackPanel _body = new() { Spacing = 0 };

    public ProfilePage(Store store, MainWindow win) : base(store, win)
    {
        Content = new ScrollViewer
        {
            Content = new Border { Padding = new Thickness(30, 24, 30, 40), Child = _body },
        };
    }

    public override async Task LoadAsync()
    {
        _body.Children.Clear();
        _body.Children.Add(Th.T("我的", 22, FontWeight.Bold, Th.Text));
        _body.Children.Add(new Border { Height = 18 });

        var u = S.User;
        var card = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
        card.Children.Add(new Border
        {
            Width = 54, Height = 54,
            CornerRadius = new CornerRadius(27),
            Background = u != null && u.VipActive ? Th.Gold : Th.SurfaceHi,
            Child = Th.T(u == null ? "N" : (u.DisplayName.Length > 0 ? u.DisplayName.Substring(0, 1).ToUpper() : "N"), 20,
                FontWeight.Bold, u != null && u.VipActive ? Th.Ink : Th.Sub),
            VerticalAlignment = VerticalAlignment.Center,
        });
        var col = new StackPanel
        {
            Spacing = 4,
            Margin = new Thickness(16, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            Children =
            {
                Th.T(u?.DisplayName ?? "未登录", 17, FontWeight.SemiBold, Th.Text),
                Th.T(u == null ? "登录后可同步会员状态与反馈" : (u.Email.Length > 0 ? u.Email : u.Username), 11,
                    FontWeight.Normal, Th.Faint),
            },
        };
        Grid.SetColumn(col, 1);
        card.Children.Add(col);

        var action = u == null
            ? Th.Btn("登录", async () => await OpenLogin(), true, null, 40)
            : Th.Ghost("退出登录", async () =>
            {
                try { await S.Api.Logout(); } catch { }
                S.SetUser(null);
                W.RefreshChips();
                await LoadAsync();
            }, null, 40);
        Grid.SetColumn(action, 2);
        card.Children.Add(action);

        _body.Children.Add(Th.Card(card, 18, 18));

        if (u != null)
        {
            _body.Children.Add(new Border { Height = 12 });
            _body.Children.Add(Th.Card(new StackPanel
            {
                Spacing = 4,
                Children =
                {
                    new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Spacing = 9,
                        Children =
                        {
                            Th.Glyph(Th.ICrown, 14, Th.Accent),
                            Th.T(u.VipActive ? "会员生效中" : "未开通会员", 13.5, FontWeight.SemiBold, Th.Accent),
                        },
                    },
                    Th.T(u.VipActive ? $"剩余 {u.DaysLeft} 天" + (u.VipUntil != null ? "  ·  " + u.VipUntil : "") : "开通后可观看全部 VIP 片源",
                        10.5, FontWeight.Normal, Th.Sub),
                },
            }, 16, 16, Th.AccentWash, Th.Accent));
        }

        _body.Children.Add(SectionTitle("会员套餐"));
        try
        {
            var plans = await S.Api.Plans();
            var row = new WrapPanel { ItemWidth = 192, ItemHeight = 96 };
            foreach (var p in plans)
            {
                var plan = p;
                var box = Th.Card(new StackPanel
                {
                    Spacing = 6,
                    Children =
                    {
                        Th.T(plan.Title, 13, FontWeight.SemiBold, Th.Text, font: Th.Arabic),
                        Th.T(plan.Days + " 天", 10, FontWeight.Normal, Th.Faint),
                        new StackPanel
                        {
                            Orientation = Orientation.Horizontal,
                            Spacing = 2,
                            Children =
                            {
                                Th.T("¥", 11, FontWeight.Normal, Th.Accent),
                                Th.T(plan.Price, 20, FontWeight.Bold, Th.Accent),
                            },
                        },
                    },
                }, 14, 14);
                box.Margin = new Thickness(0, 0, 10, 10);
                box.PointerEntered += (_, __) => box.BorderBrush = Th.Accent;
                box.PointerExited += (_, __) => box.BorderBrush = Th.Line;
                box.Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand);
                box.PointerPressed += (_, __) =>
                {
                    if (!string.IsNullOrWhiteSpace(S.Config?.SubscriptionUrl))
                    {
                        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(S.Config.SubscriptionUrl) { UseShellExecute = true }); }
                        catch { W.Toast("无法打开链接"); }
                    }
                    else W.Toast("请联系管理员开通：" + plan.Title);
                };
                row.Children.Add(box);
            }
            _body.Children.Add(row);
        }
        catch (ApiError e)
        {
            _body.Children.Add(Th.T(e.Message, 11, FontWeight.Normal, Th.Danger));
        }

        _body.Children.Add(SectionTitle("通用"));
        var settings = Th.Card(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 12,
            Children =
            {
                Th.Glyph(Th.ISettings, 14, Th.Sub),
                Th.T("服务器设置", 12.5, FontWeight.Medium, Th.Text),
                Th.T(S.Base, 10.5, FontWeight.Normal, Th.Faint),
            },
        }, 15, 14);
        settings.Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand);
        settings.PointerEntered += (_, __) => settings.BorderBrush = Th.Accent;
        settings.PointerExited += (_, __) => settings.BorderBrush = Th.Line;
        settings.PointerPressed += async (_, __) => await W.OpenSettings();
        _body.Children.Add(settings);

        _body.Children.Add(new Border { Height = 30 });
        _body.Children.Add(new TextBlock
        {
            Text = "Noqi Desktop 1.0.0  ·  Avalonia / .NET 6",
            FontSize = 9.5,
            Foreground = Th.Faint,
            HorizontalAlignment = HorizontalAlignment.Center,
        });
    }

    async Task OpenLogin()
    {
        var dlg = new LoginDialog(S);
        await dlg.ShowDialog(W);
        if (dlg.LoggedIn)
        {
            W.RefreshChips();
            await LoadAsync();
        }
    }
}
