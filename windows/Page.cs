using Avalonia;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Threading;

namespace Noqi;

public static class Images
{
    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(25) };
    static readonly Dictionary<string, Bitmap> Cache = new();

    public static Control Create(string url, double w, double h, Stretch stretch = Stretch.UniformToFill)
    {
        var holder = new Panel { Width = w, Height = h, ClipToBounds = true };
        holder.Children.Add(new Border { Background = Th.Surface });
        var img = new Image { Width = w, Height = h, Stretch = stretch, Opacity = 0 };
        holder.Children.Add(img);
        if (!string.IsNullOrWhiteSpace(url)) _ = LoadAsync(url, bmp => { img.Source = bmp; img.Opacity = 1; });
        return holder;
    }

    public static Image CreateFill(string url, double opacity = 1)
    {
        var img = new Image { Stretch = Stretch.UniformToFill, Opacity = 0, HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Stretch };
        if (!string.IsNullOrWhiteSpace(url)) _ = LoadAsync(url, bmp => { img.Source = bmp; img.Opacity = opacity; });
        return img;
    }

    public static async Task LoadAsync(string url, Action<Bitmap> apply)
    {
        try
        {
            if (Cache.TryGetValue(url, out var cached))
            {
                Dispatcher.UIThread.Post(() => apply(cached));
                return;
            }
            var bytes = await Http.GetByteArrayAsync(url).ConfigureAwait(false);
            var bmp = new Bitmap(new MemoryStream(bytes));
            Cache[url] = bmp;
            Dispatcher.UIThread.Post(() => apply(bmp));
        }
        catch { }
    }
}

public abstract class Page : UserControl
{
    protected readonly Store S;
    protected readonly MainWindow W;

    protected Page(Store store, MainWindow win)
    {
        S = store;
        W = win;
        Background = Th.Bg;
    }

    public virtual Task LoadAsync() => Task.CompletedTask;

    // ── shared building blocks ──────────────────────────────
    protected static Control SectionTitle(string text, string trailing = null, Action onTrailing = null)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), Margin = new Thickness(0, 26, 0, 13) };
        var left = new StackPanel { Orientation = Avalonia.Layout.Orientation.Horizontal, Spacing = 9 };
        left.Children.Add(new Border
        {
            Width = 3,
            Height = 14,
            CornerRadius = new CornerRadius(2),
            Background = Th.Accent,
        });
        left.Children.Add(Th.T(text, 15, FontWeight.Bold, Th.Text));
        grid.Children.Add(left);
        if (trailing != null)
        {
            var t = Th.T(trailing, 11.5, FontWeight.Medium, Th.Accent);
            var b = new Border { Child = t, Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand) };
            if (onTrailing != null) b.PointerPressed += (_, __) => onTrailing();
            Grid.SetColumn(b, 2);
            grid.Children.Add(b);
        }
        return grid;
    }

    protected static Control PosterCard(Store S, Vod v, double width, Action onClick, bool locked = false)
    {
        var height = width * 1.45;
        var stack = new StackPanel { Spacing = 8, Width = width };

        var panel = new Panel { Width = width, Height = height, ClipToBounds = true };
        panel.Children.Add(new Border
        {
            Width = width,
            Height = height,
            CornerRadius = new CornerRadius(11),
            ClipToBounds = true,
            Child = Images.Create(v.Pic, width, height),
        });
        // bottom scrim
        panel.Children.Add(new Border
        {
            Height = height * 0.45,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Bottom,
            Background = new LinearGradientBrush
            {
                StartPoint = new Avalonia.RelativePoint(0, 0, Avalonia.RelativeUnit.Relative),
                EndPoint = new Avalonia.RelativePoint(0, 1, Avalonia.RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Color.Parse("#00000000"), 0),
                    new GradientStop(Color.Parse("#CC000000"), 1),
                },
            },
        });
        if (!string.IsNullOrWhiteSpace(v.Remarks))
        {
            var remark = Th.T(v.Remarks, 9.5, FontWeight.Normal, new SolidColorBrush(Color.Parse("#D8D8DE")), maxLines: 1);
            panel.Children.Add(new Border
            {
                Child = remark,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Bottom,
                Margin = new Avalonia.Thickness(8, 0, 8, 6),
            });
        }
        var score = double.TryParse(v.Score.Split(' ')[0], out var sc) ? sc : 0;
        if (score > 0)
        {
            var badge = new Border
            {
                Background = new SolidColorBrush(Color.Parse("#A6000000")),
                CornerRadius = new CornerRadius(5),
                Padding = new Avalonia.Thickness(5, 2, 5, 2),
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top,
                Margin = new Avalonia.Thickness(6),
                Child = Th.T(score.ToString("0.0"), 9.5, FontWeight.Bold, Th.Accent),
            };
            panel.Children.Add(badge);
        }
        if (locked)
        {
            panel.Children.Add(new Border
            {
                Background = new SolidColorBrush(Color.Parse("#A6000000")),
                CornerRadius = new CornerRadius(5),
                Padding = new Avalonia.Thickness(4, 3, 4, 3),
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top,
                Margin = new Avalonia.Thickness(6),
                Child = Th.Glyph(Th.ILock, 9, Th.Accent),
            });
        }
        stack.Children.Add(new Border
        {
            CornerRadius = new CornerRadius(11),
            ClipToBounds = true,
            Child = panel,
            Cursor = new Avalonia.Input.Cursor(Avalonia.Input.StandardCursorType.Hand),
        });
        var title = Th.T(v.Name, 12, FontWeight.Medium, Th.Text, maxLines: 1, font: Th.Arabic);
        stack.Children.Add(title);

        var root = new Border { Child = stack, Background = Brushes.Transparent, Padding = new Avalonia.Thickness(0) };
        root.PointerPressed += (_, e) =>
        {
            if (e.GetCurrentPoint(root).Properties.IsLeftButtonPressed) onClick();
        };
        root.PointerEntered += (_, __) => panel.Opacity = 0.82;
        root.PointerExited += (_, __) => panel.Opacity = 1;
        return root;
    }

    protected static Control Badge(string text, IBrush fg = null, IBrush bg = null)
        => Th.Pill(text, bg ?? Th.AccentWash, fg ?? Th.Accent, 9.5);

    protected static string MetaJoin(params string[] parts)
    {
        var list = new List<string>();
        foreach (var p in parts) if (!string.IsNullOrWhiteSpace(p)) list.Add(p.Trim());
        return string.Join("  ·  ", list);
    }

    protected Control ErrorBox(string message, Action retry)
    {
        var box = new StackPanel
        {
            Spacing = 14,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            Children =
            {
                Th.Glyph(Th.IWarning, 24, Th.Faint),
                Th.T(message, 13, FontWeight.Normal, Th.Sub, wrap: true),
                Th.Ghost("重试", retry),
            },
        };
        return new ScrollViewer { Content = box, VerticalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled };
    }
}
