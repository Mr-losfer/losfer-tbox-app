using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Noqi;

public class ApiError : Exception
{
    public int Code { get; }
    public ApiError(int code, string msg) : base(msg) { Code = code; }
    public bool IsAuth => Code == 401;
    public bool IsVip => Code == 402;
}

public class SiteConfig
{
    public string SiteName = "Noqi";
    public bool RegisterOpen = true;
    public bool DetailLogin;
    public bool SiteVip;
    public bool OauthEnabled;
    public List<string> OauthTypes = new();
    public string SubscriptionUrl = "";
    public bool EmailVerify;

    public static SiteConfig Parse(JsonElement j) => new()
    {
        SiteName = Str(j, "site_name", "Noqi"),
        RegisterOpen = Bool(j, "register_open", true),
        DetailLogin = Bool(j, "detail_login"),
        SiteVip = Bool(j, "site_vip"),
        OauthEnabled = Bool(j, "oauth_enabled"),
        OauthTypes = j.TryGetProperty("oauth_types", out var t) && t.ValueKind == JsonValueKind.Array
            ? t.EnumerateArray().Select(e => e.GetString() ?? "").Where(s => s.Length > 0).ToList()
            : new List<string>(),
        SubscriptionUrl = Str(j, "subscription_url"),
        EmailVerify = Bool(j, "email_verify"),
    };

    internal static string Str(JsonElement j, string key, string def = "")
        => j.TryGetProperty(key, out var v) ? (v.ValueKind == JsonValueKind.String ? v.GetString() ?? def : v.ToString()) : def;

    internal static int Int(JsonElement j, string key, int def = 0)
    {
        if (!j.TryGetProperty(key, out var v)) return def;
        if (v.ValueKind == JsonValueKind.Number) return v.TryGetInt32(out var i) ? i : def;
        return int.TryParse(v.ToString(), out var p) ? p : def;
    }

    internal static bool Bool(JsonElement j, string key, bool def = false)
    {
        if (!j.TryGetProperty(key, out var v)) return def;
        return v.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number => v.TryGetInt32(out var i) && i != 0,
            JsonValueKind.String => v.GetString() == "1" || v.GetString() == "true",
            _ => def,
        };
    }
}

public class SourceSite
{
    public string Code = "";
    public string Name = "";
    public bool IsDefault;
    public bool IsVip;

    public static SourceSite Parse(JsonElement j) => new()
    {
        Code = SiteConfig.Str(j, "code"),
        Name = SiteConfig.Str(j, "name"),
        IsDefault = SiteConfig.Int(j, "is_default") == 1,
        IsVip = SiteConfig.Int(j, "is_vip") == 1,
    };
}

public class VodClass
{
    public string Id = "";
    public string Name = "";
}

public class Episode
{
    public string Name = "";
    public string PlayId = "";
    public string Play => PlayId.Split('|').FirstOrDefault() ?? PlayId;
    public int Q
    {
        get
        {
            var p = PlayId.Split('|');
            if (p.Length >= 3 && int.TryParse(p[2], out var q3)) return Math.Max(1, q3);
            if (p.Length == 2 && int.TryParse(p[1], out var q2)) return Math.Max(1, q2);
            return 1;
        }
    }
    public string Label => string.IsNullOrWhiteSpace(Name) ? Q.ToString() : Name;
}

public class PlaySource
{
    public string Name = "";
    public List<Episode> Episodes = new();
}

public class Vod
{
    public string Id = "";
    public string Name = "";
    public string Pic = "";
    public string Remarks = "";
    public string TypeName = "";
    public string Year = "";
    public string Area = "";
    public string Score = "";
    public string Content = "";
    public string Actor = "";
    public string Director = "";
    public List<PlaySource> Sources = new();

    public bool HasEpisodes => Sources.Count > 0 && Sources[0].Episodes.Count > 0;
    public List<Episode> Episodes => Sources.Count == 0 ? new List<Episode>() : Sources[0].Episodes;

    public static Vod Parse(JsonElement j)
    {
        var v = new Vod
        {
            Id = SiteConfig.Str(j, "vod_id"),
            Name = SiteConfig.Str(j, "vod_name"),
            Pic = SiteConfig.Str(j, "vod_pic"),
            Remarks = SiteConfig.Str(j, "vod_remarks"),
            TypeName = SiteConfig.Str(j, "type_name"),
            Year = SiteConfig.Str(j, "vod_year"),
            Area = SiteConfig.Str(j, "vod_area"),
            Score = SiteConfig.Str(j, "vod_score"),
            Content = SiteConfig.Str(j, "vod_content"),
            Actor = SiteConfig.Str(j, "vod_actor"),
            Director = SiteConfig.Str(j, "vod_director"),
        };
        v.Sources = ParseSources(j);
        return v;
    }

    static List<PlaySource> ParseSources(JsonElement j)
    {
        var list = new List<PlaySource>();
        if (j.TryGetProperty("vod_play_sources", out var raw) && raw.ValueKind == JsonValueKind.Array)
        {
            foreach (var s in raw.EnumerateArray())
            {
                var eps = new List<Episode>();
                if (s.TryGetProperty("episodes", out var es) && es.ValueKind == JsonValueKind.Array)
                {
                    foreach (var e in es.EnumerateArray())
                    {
                        var pid = SiteConfig.Str(e, "playId");
                        if (pid.Length == 0) continue;
                        eps.Add(new Episode { Name = SiteConfig.Str(e, "name"), PlayId = pid });
                    }
                }
                if (eps.Count > 0) list.Add(new PlaySource { Name = SiteConfig.Str(s, "name"), Episodes = eps });
            }
        }
        if (list.Count > 0) return list;

        var url = SiteConfig.Str(j, "vod_play_url");
        if (string.IsNullOrWhiteSpace(url)) return list;
        var froms = SiteConfig.Str(j, "vod_play_from").Split("$$$");
        var groups = url.Split("$$$");
        for (var g = 0; g < groups.Length; g++)
        {
            var eps = new List<Episode>();
            foreach (var chunk in groups[g].Split('#'))
            {
                var c = chunk.Trim();
                if (c.Length == 0) continue;
                var cut = c.LastIndexOf('$');
                if (cut < 0) continue;
                var name = c.Substring(0, cut).Trim();
                var pid = c.Substring(cut + 1).Trim();
                if (pid.Length == 0) continue;
                eps.Add(new Episode { Name = string.IsNullOrEmpty(name) ? (eps.Count + 1).ToString() : name, PlayId = pid });
            }
            if (eps.Count > 0)
                list.Add(new PlaySource { Name = g < froms.Length && froms[g].Length > 0 ? froms[g] : (g + 1).ToString(), Episodes = eps });
        }
        return list;
    }
}

public class PageResult
{
    public List<Vod> Items = new();
    public int Page = 1;
    public int PageCount = 1;
    public int Total;
}

public class HotItem
{
    public string SiteCode = "";
    public string Id = "";
    public string Name = "";
    public string Pic = "";
    public int Plays;

    public Vod ToVod() => new() { Id = Id, Name = Name, Pic = Pic, Remarks = Plays > 0 ? Plays.ToString() : "" };

    public static HotItem Parse(JsonElement j) => new()
    {
        SiteCode = SiteConfig.Str(j, "site_code"),
        Id = SiteConfig.Str(j, "vod_id"),
        Name = SiteConfig.Str(j, "vod_name"),
        Pic = SiteConfig.Str(j, "vod_pic"),
        Plays = SiteConfig.Int(j, "plays"),
    };
}

public class Plan
{
    public int Id;
    public string Title = "";
    public int Days;
    public string Price = "";
}

public class NoticeItem
{
    public int Id;
    public string Title = "";
    public string Content = "";
    public long CreatedAt;
}

public class User
{
    public int Id;
    public string Username = "";
    public string Email = "";
    public string Apikey = "";
    public string PlayToken = "";
    public bool VipActive;
    public int DaysLeft;
    public string VipUntil;
    public string Role = "user";

    public string DisplayName => !string.IsNullOrWhiteSpace(Username) ? Username : (Email.Contains('@') ? Email.Split('@')[0] : Email);

    public static User Parse(JsonElement j) => new()
    {
        Id = SiteConfig.Int(j, "id"),
        Username = SiteConfig.Str(j, "username"),
        Email = SiteConfig.Str(j, "email"),
        Apikey = SiteConfig.Str(j, "apikey"),
        PlayToken = SiteConfig.Str(j, "play_token"),
        VipActive = SiteConfig.Bool(j, "vip_active"),
        DaysLeft = SiteConfig.Int(j, "days_left"),
        VipUntil = j.TryGetProperty("vip_until", out var u) && u.ValueKind == JsonValueKind.String ? u.GetString() : null,
        Role = SiteConfig.Str(j, "role", "user"),
    };
}

public class PlayInfo
{
    public string Url = "";
    public Dictionary<string, string> Headers = new();
}

public class Api
{
    static readonly HttpClient Http = new(new HttpClientHandler
    {
        AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
    })
    {
        Timeout = TimeSpan.FromSeconds(30),
    };

    public string Base { get; }
    public string Apikey { get; }

    public Api(string baseUrl, string apikey = null)
    {
        Base = (baseUrl ?? "").TrimEnd('/');
        Apikey = apikey;
    }

    public static string Normalize(string raw)
    {
        var v = (raw ?? "").Trim();
        if (v.Length == 0) return v;
        if (!v.StartsWith("http://") && !v.StartsWith("https://")) v = "https://" + v;
        return v.TrimEnd('/');
    }

    HttpRequestMessage Req(string path)
    {
        var r = new HttpRequestMessage(HttpMethod.Get, Base + path);
        r.Headers.TryAddWithoutValidation("Accept", "application/json");
        if (!string.IsNullOrEmpty(Apikey)) r.Headers.TryAddWithoutValidation("Authorization", "Bearer " + Apikey);
        return r;
    }

    async Task<JsonElement> GetRaw(string path)
    {
        HttpResponseMessage resp;
        try
        {
            resp = await Http.SendAsync(Req(path)).ConfigureAwait(false);
        }
        catch (Exception)
        {
            throw new ApiError(-1, "网络连接失败，请检查网络后重试");
        }
        var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
        JsonElement root;
        try
        {
            root = JsonDocument.Parse(body).RootElement;
        }
        catch
        {
            throw new ApiError((int)resp.StatusCode, "服务器响应异常 (" + (int)resp.StatusCode + ")");
        }
        return root;
    }

    async Task<JsonElement> Get(string path)
    {
        var root = await GetRaw(path).ConfigureAwait(false);
        if (root.ValueKind != JsonValueKind.Object) throw new ApiError(-1, "响应格式异常");
        var code = SiteConfig.Int(root, "code");
        if (code != 0) throw new ApiError(code, Msg(root, code));
        return root;
    }

    static string Msg(JsonElement root, int code)
    {
        var m = SiteConfig.Str(root, "msg");
        if (!string.IsNullOrWhiteSpace(m)) return m;
        return code switch
        {
            401 => "请先登录",
            402 => "该片源仅限会员",
            403 => "账号受限或权限不足",
            404 => "资源不存在",
            429 => "请求过于频繁，请稍后再试",
            502 => "片源异常，请切换片源重试",
            _ => "请求失败 (" + code + ")",
        };
    }

    async Task<JsonElement> Post(string path, object body)
    {
        var json = JsonSerializer.Serialize(body);
        HttpResponseMessage resp;
        try
        {
            var r = new HttpRequestMessage(HttpMethod.Post, Base + path)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            };
            if (!string.IsNullOrEmpty(Apikey)) r.Headers.TryAddWithoutValidation("Authorization", "Bearer " + Apikey);
            resp = await Http.SendAsync(r).ConfigureAwait(false);
        }
        catch (Exception)
        {
            throw new ApiError(-1, "网络连接失败，请检查网络后重试");
        }
        var text = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
        JsonElement root;
        try { root = JsonDocument.Parse(text).RootElement; }
        catch { throw new ApiError((int)resp.StatusCode, "服务器响应异常"); }
        var code = SiteConfig.Int(root, "code");
        if (code != 0) throw new ApiError(code, Msg(root, code));
        return root;
    }

    public async Task<SiteConfig> Config() => SiteConfig.Parse(await Get("/api/portal/config"));

    public async Task<List<SourceSite>> Sources()
    {
        var root = await Get("/api/portal/sources");
        var list = new List<SourceSite>();
        if (root.TryGetProperty("list", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var e in arr.EnumerateArray()) list.Add(SourceSite.Parse(e));
        return list;
    }

    public async Task<List<HotItem>> Hot(int limit = 12)
    {
        var root = await Get("/api/portal/hot?limit=" + limit);
        var list = new List<HotItem>();
        if (root.TryGetProperty("list", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var e in arr.EnumerateArray()) list.Add(HotItem.Parse(e));
        return list;
    }

    public async Task<List<NoticeItem>> Notices()
    {
        var root = await Get("/api/portal/notices");
        var list = new List<NoticeItem>();
        if (root.TryGetProperty("list", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var e in arr.EnumerateArray())
                list.Add(new NoticeItem
                {
                    Id = SiteConfig.Int(e, "id"),
                    Title = SiteConfig.Str(e, "title"),
                    Content = SiteConfig.Str(e, "content"),
                    CreatedAt = long.TryParse(SiteConfig.Str(e, "created_at"), out var ts) ? ts : SiteConfig.Int(e, "created_at"),
                });
        return list;
    }

    public async Task<List<Plan>> Plans()
    {
        var root = await Get("/api/portal/plans");
        var list = new List<Plan>();
        if (root.TryGetProperty("list", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var e in arr.EnumerateArray())
                list.Add(new Plan
                {
                    Id = SiteConfig.Int(e, "id"),
                    Title = SiteConfig.Str(e, "title"),
                    Days = SiteConfig.Int(e, "days"),
                    Price = SiteConfig.Str(e, "price"),
                });
        return list;
    }

    public async Task<(List<VodClass> Classes, PageResult Page)> SiteHome(string code)
    {
        var root = await Get("/api/portal/site/" + code + "/classes");
        var classes = new List<VodClass>();
        if (root.TryGetProperty("class", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var e in arr.EnumerateArray())
                classes.Add(new VodClass { Id = SiteConfig.Str(e, "type_id"), Name = SiteConfig.Str(e, "type_name") });
        return (classes, PageOf(root));
    }

    public async Task<PageResult> List(string code, string t = "", int pg = 1)
        => PageOf(await Get("/api/portal/site/" + code + "/list?t=" + Uri.EscapeDataString(t) + "&pg=" + pg));

    public async Task<PageResult> Search(string code, string wd, int pg = 1)
        => PageOf(await Get("/api/portal/site/" + code + "/search?wd=" + Uri.EscapeDataString(wd) + "&pg=" + pg));

    public async Task<Vod> Detail(string code, string vid)
    {
        var root = await Get("/api/portal/site/" + code + "/detail?vid=" + Uri.EscapeDataString(vid));
        var page = PageOf(root);
        return page.Items.FirstOrDefault();
    }

    static PageResult PageOf(JsonElement root)
    {
        var p = new PageResult
        {
            Page = SiteConfig.Int(root, "page", 1),
            PageCount = Math.Max(1, SiteConfig.Int(root, "pagecount", 1)),
            Total = SiteConfig.Int(root, "total"),
        };
        if (root.TryGetProperty("list", out var arr) && arr.ValueKind == JsonValueKind.Array)
            foreach (var e in arr.EnumerateArray()) p.Items.Add(Vod.Parse(e));
        return p;
    }

    public async Task<PlayInfo> Play(string code, string play, int q, string token)
    {
        var url = "/api/play_v2/" + code + "?play=" + Uri.EscapeDataString(play) + "&q=" + q + "&format=json";
        if (!string.IsNullOrEmpty(token)) url += "&token=" + Uri.EscapeDataString(token);
        var root = await GetRaw(url);
        if (root.ValueKind == JsonValueKind.Object)
        {
            var c = SiteConfig.Int(root, "code");
            if (root.TryGetProperty("code", out _) && c != 0) throw new ApiError(c, Msg(root, c));
            var info = new PlayInfo();
            if (root.TryGetProperty("url", out var u))
            {
                if (u.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in u.EnumerateArray())
                    {
                        var s = item.GetString() ?? "";
                        if (s.StartsWith("http")) { info.Url = s; break; }
                    }
                    if (info.Url.Length == 0 && u.GetArrayLength() > 0) info.Url = u[u.GetArrayLength() - 1].GetString() ?? "";
                }
                else if (u.ValueKind == JsonValueKind.String)
                {
                    info.Url = u.GetString() ?? "";
                }
            }
            if (root.TryGetProperty("header", out var h) && h.ValueKind == JsonValueKind.Object)
                foreach (var prop in h.EnumerateObject())
                {
                    var val = prop.Value.ValueKind == JsonValueKind.String ? prop.Value.GetString() : prop.Value.ToString();
                    if (!string.IsNullOrWhiteSpace(val)) info.Headers[prop.Name] = val;
                }
            if (info.Url.Length == 0) throw new ApiError(400, "播放地址解析失败");
            return info;
        }
        throw new ApiError(-1, "播放地址解析失败");
    }

    public async Task<User> Login(string username, string password)
    {
        var root = await Post("/api/portal/login", new { username, password });
        if (root.TryGetProperty("user", out var u)) return User.Parse(u);
        throw new ApiError(401, "账号或密码错误");
    }

    public async Task<(User user, bool verify)> Register(string email, string password)
    {
        var root = await Post("/api/portal/register", new { email, password });
        if (root.TryGetProperty("user", out var u)) return (User.Parse(u), false);
        return (null, SiteConfig.Bool(root, "verify_required"));
    }

    public async Task<User> Me()
    {
        var root = await Get("/api/portal/me");
        if (root.TryGetProperty("user", out var u)) return User.Parse(u);
        throw new ApiError(401, "请先登录");
    }

    public Task ChangePassword(string oldPwd, string newPwd) => Post("/api/portal/password", new { old = oldPwd, @new = newPwd });
    public Task ResetKey() => Post("/api/portal/reset_key", new { });
    public Task ResetPlayToken() => Post("/api/portal/reset_play_token", new { });
    public Task Logout() => Post("/api/portal/logout", new { });
    public Task Feedback(string content) => Post("/api/portal/feedback", new { type = "feedback", content });
}

public static class Format
{
    public static string Date(long epochSeconds)
    {
        if (epochSeconds <= 0) return "";
        var d = DateTimeOffset.FromUnixTimeSeconds(epochSeconds).ToLocalTime();
        return d.ToString("yyyy.MM.dd", CultureInfo.InvariantCulture);
    }
}
