using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Templates;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;

namespace Noqi;

public class LoginDialog : Window
{
    readonly Store S;
    readonly TextBox _user = new();
    readonly TextBox _pwd = new();
    readonly TextBlock _err;
    readonly TextBlock _hint;
    readonly TextBlock _title;
    readonly Control _submit;
    bool _register;
    bool _busy;

    public bool LoggedIn { get; private set; }

    public LoginDialog(Store store)
    {
        S = store;
        Width = 420;
        Height = 520;
        CanResize = false;
        SystemDecorations = SystemDecorations.None;
        Background = new SolidColorBrush(Color.Parse("#0B0B0F"));
        WindowStartupLocation = WindowStartupLocation.CenterOwner;

        _err = Th.T("", 11, FontWeight.Normal, Th.Danger, wrap: true);
        _hint = Th.T("", 11, FontWeight.Normal, Th.Accent, wrap: true);
        _title = Th.T("登录 " + S.SiteName, 20, FontWeight.Bold, Th.Text);
        _submit = Th.Btn("登录", () => _ = Submit(), true, null, 46);

        _user.Watermark = "邮箱 / 用户名";
        _pwd.Watermark = "密码";
        _pwd.PasswordChar = '●';
        foreach (var tb in new[] { _user, _pwd })
        {
            tb.Height = 46;
            tb.FontSize = 13;
            tb.CornerRadius = new CornerRadius(11);
            tb.Background = Th.Surface;
            tb.Foreground = Th.Text;
            tb.BorderBrush = Th.Line;
            tb.Padding = new Thickness(14, 0, 14, 0);
        }
        _pwd.KeyDown += (_, e) => { if (e.Key == Key.Enter) _ = Submit(); };

        var body = new StackPanel { Spacing = 12, Margin = new Thickness(28, 22, 28, 24) };
        body.Children.Add(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 11,
            Children =
            {
                new Border
                {
                    Width = 38, Height = 38,
                    CornerRadius = new CornerRadius(11),
                    Background = Th.Gold,
                    Child = Th.Glyph(Th.IPlay, 16, Th.Ink),
                },
                new StackPanel
                {
                    Spacing = 2,
                    VerticalAlignment = VerticalAlignment.Center,
                    Children = { _title, Th.T("登录以同步会员与反馈", 10.5, FontWeight.Normal, Th.Faint) },
                },
            },
        });
        body.Children.Add(new Border { Height = 8 });
        body.Children.Add(_user);
        body.Children.Add(_pwd);
        body.Children.Add(_err);
        body.Children.Add(_hint);
        body.Children.Add(new Border { Height = 4 });
        body.Children.Add(_submit);

        var toggle = new TextBlock
        {
            Text = "还没有账号？注册",
            FontSize = 11.5,
            Foreground = Th.Sub,
            HorizontalAlignment = HorizontalAlignment.Center,
            Cursor = new Cursor(StandardCursorType.Hand),
            Margin = new Thickness(0, 4, 0, 0),
        };
        toggle.PointerPressed += (_, __) => SwitchMode();
        body.Children.Add(toggle);

        var close = new Border
        {
            Child = Th.Glyph(Th.IClose, 10, Th.Faint),
            Width = 34,
            Height = 30,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
        };
        close.PointerPressed += (_, __) => Close();
        close.PointerEntered += (_, __) => close.Background = new SolidColorBrush(Color.Parse("#1A1A22"));
        close.PointerExited += (_, __) => close.Background = Brushes.Transparent;

        var root = new Panel();
        root.Children.Add(new Border
        {
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(18),
            Background = new SolidColorBrush(Color.Parse("#0B0B0F")),
            Child = body,
        });
        root.Children.Add(close);
        Content = root;

        Opened += (_, __) => _user.Focus();
        KeyDown += (_, e) => { if (e.Key == Key.Escape) Close(); };
    }

    void SwitchMode()
    {
        _register = !_register;
        _title.Text = _register ? "创建账号" : "登录 " + S.SiteName;
        _user.Watermark = _register ? "邮箱" : "邮箱 / 用户名";
        ((Border)_submit).Child = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 7,
            Children =
            {
                Th.T(_register ? "注册" : "登录", 13.5, FontWeight.SemiBold, Th.Ink),
            },
        };
        _err.Text = "";
    }

    async Task Submit()
    {
        if (_busy) return;
        var u = _user.Text?.Trim() ?? "";
        var p = _pwd.Text ?? "";
        _err.Text = "";
        _hint.Text = "";
        if (u.Length == 0 || p.Length == 0)
        {
            _err.Text = "请填写完整信息";
            return;
        }
        if (p.Length < 6)
        {
            _err.Text = "密码至少 6 位";
            return;
        }
        _busy = true;
        try
        {
            if (_register)
            {
                var (user, verify) = await S.Api.Register(u, p);
                if (verify)
                {
                    _hint.Text = "请前往邮箱点击激活链接";
                    return;
                }
                if (user == null) { _err.Text = "注册失败"; return; }
                S.SetUser(user);
            }
            else
            {
                var user = await S.Api.Login(u, p);
                S.SetUser(user);
            }
            LoggedIn = true;
            Close();
        }
        catch (ApiError e)
        {
            _err.Text = e.Message;
        }
        catch (Exception)
        {
            _err.Text = "网络异常，请稍后重试";
        }
        finally
        {
            _busy = false;
        }
    }
}

public class SettingsDialog : Window
{
    readonly TextBox _base;
    readonly Store S;
    public bool Saved { get; private set; }
    public bool FontChanged { get; private set; }

    public SettingsDialog(Store store)
    {
        S = store;
        Width = 460;
        Height = 340;
        CanResize = false;
        SystemDecorations = SystemDecorations.None;
        Background = new SolidColorBrush(Color.Parse("#0B0B0F"));
        WindowStartupLocation = WindowStartupLocation.CenterOwner;

        _base = new TextBox
        {
            Text = S.Base,
            Height = 44,
            FontSize = 13,
            CornerRadius = new CornerRadius(11),
            Background = Th.Surface,
            Foreground = Th.Text,
            BorderBrush = Th.Line,
            Padding = new Thickness(14, 0, 14, 0),
            Watermark = "http://test3.noqi.pro:8090",
        };

        var body = new StackPanel { Spacing = 12, Margin = new Thickness(26, 22, 26, 22) };
        body.Children.Add(Th.T("服务器地址", 16, FontWeight.Bold, Th.Text));
        body.Children.Add(Th.T("修改后将重新加载站点配置", 10.5, FontWeight.Normal, Th.Faint));
        body.Children.Add(_base);

        body.Children.Add(Th.T("维语字体", 16, FontWeight.Bold, Th.Text));
        body.Children.Add(Th.T("即时生效，可随时换回", 10.5, FontWeight.Normal, Th.Faint));

        var fontBox = new ComboBox
        {
            Height = 44,
            FontSize = 13,
            Background = Th.Surface,
            Foreground = Th.Text,
            BorderBrush = Th.Line,
            CornerRadius = new CornerRadius(11),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            ItemsSource = Fonts.All,
            SelectedIndex = Math.Max(0, Fonts.All.FindIndex(f => f.Id == S.Font)),
            ItemTemplate = new FuncDataTemplate<FontOption>((f, _) => new TextBlock
            {
                Text = f.Label,
                FontFamily = f.Font,
                FontSize = 13.5,
                Foreground = Th.Text,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(2, 0, 2, 0),
            }),
        };
        fontBox.SelectionChanged += (_, __) =>
        {
            if (fontBox.SelectedItem is not FontOption fo) return;
            Th.SetArabic(fo.Id);
            S.SetFont(fo.Id);
            FontChanged = true;
        };
        body.Children.Add(fontBox);

        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, Margin = new Thickness(0, 6, 0, 0) };
        row.Children.Add(Th.Btn("保存", Save, true, null, 42));
        row.Children.Add(Th.Ghost("取消", Close, null, 42));
        body.Children.Add(row);

        Content = new Border
        {
            BorderBrush = Th.Line,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(18),
            Background = new SolidColorBrush(Color.Parse("#0B0B0F")),
            Child = body,
        };
        Opened += (_, __) => _base.Focus();
        KeyDown += (_, e) => { if (e.Key == Key.Escape) Close(); };
    }

    void Save()
    {
        var v = Api.Normalize(_base.Text ?? "");
        if (v.Length == 0) return;
        S.SetBase(v);
        Saved = true;
        Close();
    }
}
