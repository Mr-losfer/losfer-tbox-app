using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;

namespace Noqi;

public static class Th
{
    public static readonly Color BgColor = Color.Parse("#07070A");
    public static readonly Color SurfaceColor = Color.Parse("#131318");
    public static readonly Color SurfaceHiColor = Color.Parse("#1C1C23");
    public static readonly Color LineColor = Color.Parse("#1FFFFFFF");
    public static readonly Color TextColor = Color.Parse("#F5F5F7");
    public static readonly Color SubColor = Color.Parse("#9B9BA6");
    public static readonly Color FaintColor = Color.Parse("#5E5E69");
    public static readonly Color AccentColor = Color.Parse("#EFBF6B");
    public static readonly Color AccentDeepColor = Color.Parse("#D79A3F");
    public static readonly Color DangerColor = Color.Parse("#FF5F5F");

    public static readonly IBrush Bg = new SolidColorBrush(BgColor);
    public static readonly IBrush Surface = new SolidColorBrush(SurfaceColor);
    public static readonly IBrush SurfaceHi = new SolidColorBrush(SurfaceHiColor);
    public static readonly IBrush Line = new SolidColorBrush(LineColor);
    public static readonly IBrush Text = new SolidColorBrush(TextColor);
    public static readonly IBrush Sub = new SolidColorBrush(SubColor);
    public static readonly IBrush Faint = new SolidColorBrush(FaintColor);
    public static readonly IBrush Accent = new SolidColorBrush(AccentColor);
    public static readonly IBrush Danger = new SolidColorBrush(DangerColor);
    public static readonly IBrush AccentWash = new SolidColorBrush(Color.Parse("#1FEFBF6B"));
    public static readonly IBrush Ink = new SolidColorBrush(Color.Parse("#14100A"));

    public static readonly LinearGradientBrush Gold = new()
    {
        StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
        EndPoint = new RelativePoint(1, 1, RelativeUnit.Relative),
        GradientStops =
        {
            new GradientStop(Color.Parse("#F8D695"), 0),
            new GradientStop(Color.Parse("#E3A94F"), 1),
        },
    };

    public static readonly FontFamily Latin = new("Segoe UI");
    public static FontFamily Arabic { get; private set; } = Fonts.Default.Font;

    /// <summary>切换维语字体（设置页调用，之后需要重建页面）</summary>
    public static void SetArabic(string id) => Arabic = Fonts.Resolve(id);
    public static readonly FontFamily Icon = new("Segoe MDL2 Assets");

    public const string IHome = "\uE80F";
    public const string ISearch = "\uE721";
    public const string ILibrary = "\uE8F1";
    public const string IPerson = "\uE77B";
    public const string ISettings = "\uE713";
    public const string IPlay = "\uE768";
    public const string IPause = "\uE769";
    public const string IBack = "\uE72B";
    public const string IChevronRight = "\uE76C";
    public const string IDown = "\uE70D";
    public const string ILock = "\uE72E";
    public const string ICrown = "\uE735";
    public const string IRefresh = "\uE72C";
    public const string IList = "\uE8FD";
    public const string IStar = "\uE734";
    public const string IClose = "\uE711";
    public const string IMinimize = "\uE921";
    public const string IMaximize = "\uE922";
    public const string IRestore = "\uE923";
    public const string IFullscreen = "\uE740";
    public const string IVolume = "\uE767";
    public const string ISkipNext = "\uE893";
    public const string IForward = "\uE892";
    public const string IRewind = "\uE892";
    public const string IWarning = "\uE7BA";
    public const string IInfo = "\uE946";

    public static TextBlock T(string text, double size = 14, FontWeight? weight = null, IBrush fg = null,
        bool wrap = false, int maxLines = 0, FontFamily font = null)
    {
        var tb = new TextBlock
        {
            Text = text,
            FontSize = size,
            Foreground = fg ?? Text,
            FontFamily = font ?? Latin,
            FontWeight = weight ?? FontWeight.Normal,
            TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap,
            VerticalAlignment = VerticalAlignment.Center,
        };
        if (maxLines > 0)
        {
            tb.MaxLines = maxLines;
            tb.TextTrimming = TextTrimming.CharacterEllipsis;
        }
        else if (!wrap)
        {
            tb.TextTrimming = TextTrimming.CharacterEllipsis;
        }
        return tb;
    }

    public static TextBlock Glyph(string glyph, double size = 16, IBrush fg = null) => new()
    {
        Text = glyph,
        FontSize = size,
        Foreground = fg ?? Text,
        FontFamily = Icon,
        VerticalAlignment = VerticalAlignment.Center,
        HorizontalAlignment = HorizontalAlignment.Center,
    };

    public static Border Card(Control child, double padding = 0, double radius = 16, IBrush bg = null, IBrush border = null)
        => new()
        {
            Child = child,
            Padding = new Thickness(padding),
            CornerRadius = new CornerRadius(radius),
            Background = bg ?? Surface,
            BorderBrush = border ?? Line,
            BorderThickness = new Thickness(1),
            ClipToBounds = true,
        };

    public static Control Btn(string label, Action onClick, bool primary = true, string icon = null, double height = 44)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 7 };
        if (icon != null) row.Children.Add(Glyph(icon, 14, primary ? Ink : Text));
        row.Children.Add(T(label, 13.5, FontWeight.SemiBold, primary ? Ink : Text));
        var b = new Border
        {
            Child = row,
            Height = height,
            Padding = new Thickness(20, 0, 20, 0),
            CornerRadius = new CornerRadius(12),
            Background = primary ? Gold : Surface,
            BorderBrush = primary ? null : Line,
            BorderThickness = primary ? new Thickness(0) : new Thickness(1),
            Cursor = new Cursor(StandardCursorType.Hand),
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Center,
        };
        b.PointerPressed += (_, e) => { if (e.GetCurrentPoint(b).Properties.IsLeftButtonPressed) onClick(); };
        b.PointerEntered += (_, __) => b.Opacity = 0.88;
        b.PointerExited += (_, __) => b.Opacity = 1;
        return b;
    }

    public static Control Ghost(string label, Action onClick, string icon = null, double height = 40)
        => Btn(label, onClick, false, icon, height);

    public static Border Pill(string text, IBrush bg = null, IBrush fg = null, double size = 10.5)
        => new()
        {
            Child = T(text, size, FontWeight.SemiBold, fg ?? Accent),
            Background = bg ?? AccentWash,
            CornerRadius = new CornerRadius(6),
            Padding = new Thickness(7, 3, 7, 3),
            VerticalAlignment = VerticalAlignment.Center,
        };

    public static Control Hoverish(Border b, IBrush normal, IBrush hover)
    {
        b.PointerEntered += (_, __) => b.Background = hover;
        b.PointerExited += (_, __) => b.Background = normal;
        return b;
    }

    public static Control Divider() => new Border { Height = 1, Background = Line, Margin = new Thickness(0, 10, 0, 10) };

    public static Border Spinner()
    {
        var pb = new ProgressBar
        {
            IsIndeterminate = true,
            Width = 90,
            Height = 3,
            Foreground = Accent,
            Background = new SolidColorBrush(Color.Parse("#22FFFFFF")),
            CornerRadius = new CornerRadius(2),
        };
        return new Border
        {
            Child = pb,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
    }
}
