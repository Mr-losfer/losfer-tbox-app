using System.Collections.Generic;
using System.Linq;
using Avalonia.Media;

namespace Noqi;

/// <summary>可选维吾尔语字体（与移动端同一批文件，随包内置）。</summary>
public class FontOption
{
    public string Id { get; init; } = "";
    public string Label { get; init; } = "";
    public string Note { get; init; } = "";
    /// <summary>字体内部家族名，用于 avares:// 引用</summary>
    public string Family { get; init; } = "";

    public FontFamily Font => new($"avares://Noqi/Assets/Fonts#{Family}, avares://Noqi/Assets/Fonts#Noto Sans Arabic, Microsoft YaHei, Segoe UI");
    public override string ToString() => Label;
}

public static class Fonts
{
    public static readonly List<FontOption> All = new()
    {
        new() { Id = "ALKATIPAsliya", Label = "ALKATIP Asliya", Note = "经典正文体 · 默认", Family = "ALKATIP Asliye" },
        new() { Id = "ALKATIPBasma", Label = "ALKATIP Basma", Note = "报刊印刷体", Family = "ALKATIP Basma" },
        new() { Id = "ALKATIPKitab", Label = "ALKATIP Kitab", Note = "书籍排版体", Family = "ALKATIP Kitab" },
        new() { Id = "ALKATIPKufi", Label = "ALKATIP Kufi", Note = "库法体 · 几何感", Family = "ALKATIP Kufi" },
        new() { Id = "ALKATIPTalik", Label = "ALKATIP Talik", Note = "塔利格体 · 手写", Family = "ALKATIP Talik" },
        new() { Id = "AlpsoftBasmaB", Label = "Alpsoft Basma B", Note = "现代印刷 · 锐利", Family = "Alpsoft Basma" },
        new() { Id = "AlpsoftNesq", Label = "Alpsoft Nesq", Note = "纳斯赫体", Family = "Alpsoft Nesq" },
        new() { Id = "AlpsoftKufi", Label = "Alpsoft Kufi", Note = "库法体 · 标题", Family = "Alpsoft Kufi" },
        new() { Id = "UKIJTuz", Label = "UKIJ Tuz", Note = "UKIJ 标准正体", Family = "UKIJ Tuz" },
        new() { Id = "UUSUNAsliya", Label = "UUS UN Asliya", Note = "方正结构 · 紧凑", Family = "UUS UN Asliya" },
    };

    public static FontOption Default => All[0];

    public static FontOption ById(string id) =>
        All.FirstOrDefault(f => f.Id == id) ?? Default;

    public static FontFamily Resolve(string id) => ById(id).Font;
}
