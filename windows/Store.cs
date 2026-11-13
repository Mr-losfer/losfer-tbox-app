using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Noqi;

public class Store
{
    public const string DefaultBase = "http://test3.noqi.pro:8090";

    public string Base = DefaultBase;
    public string SourceCode = "";
    public string Font = Fonts.Default.Id;
    public User User;
    public SiteConfig Config;
    public List<SourceSite> Sources = new();

    Api _api;

    public Api Api
    {
        get
        {
            if (_api == null) _api = new Api(Base, User?.Apikey);
            return _api;
        }
    }

    static string Dir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Noqi");
    static string FilePath => Path.Combine(Dir, "settings.json");

    class Dto
    {
        public string Base { get; set; }
        public string Source { get; set; }
        public string Font { get; set; }
        public User User { get; set; }
    }

    public void Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return;
            var dto = JsonSerializer.Deserialize<Dto>(File.ReadAllText(FilePath));
            if (dto == null) return;
            // 旧版本默认域名自动跟随新域名（用户手动改过的不动）
            if (!string.IsNullOrWhiteSpace(dto.Base) && dto.Base != "https://x.noqi.pro") Base = dto.Base;
            if (!string.IsNullOrWhiteSpace(dto.Font)) Font = dto.Font;
            if (!string.IsNullOrWhiteSpace(dto.Source)) SourceCode = dto.Source;
            User = dto.User;
            if (User != null && string.IsNullOrEmpty(User.Apikey)) User = null;
        }
        catch { }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Dir);
            var dto = new Dto { Base = Base, Source = SourceCode, Font = Font, User = User };
            File.WriteAllText(FilePath, JsonSerializer.Serialize(dto, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }

    public SourceSite Current
    {
        get
        {
            if (Sources.Count == 0) return null;
            return Sources.FirstOrDefault(s => s.Code == SourceCode)
                ?? Sources.FirstOrDefault(s => s.IsDefault)
                ?? Sources[0];
        }
    }

    public string SiteName => Config?.SiteName ?? "Noqi";

    public SourceSite ByCode(string code) =>
        Sources.FirstOrDefault(x => x.Code == code);

    public bool CanPlay(SourceSite site)
    {
        if (site == null) return false;
        if (Config == null || !Config.SiteVip) return true;
        if (!site.IsVip) return true;
        return User?.VipActive == true;
    }

    public async Task BootAsync()
    {
        Config = await Api.Config();
        Sources = await Api.Sources();
        if (Sources.Count > 0)
        {
            var cur = Sources.FirstOrDefault(s => s.Code == SourceCode);
            if (cur == null) SourceCode = Current?.Code ?? "";
        }
        if (User != null)
        {
            try
            {
                User = await Api.Me();
                _api = null;
                Save();
            }
            catch (ApiError e)
            {
                if (e.IsAuth)
                {
                    User = null;
                    _api = null;
                    Save();
                }
            }
        }
    }

    public void SetFont(string id)
    {
        Font = id;
        Save();
    }

    public void SetBase(string raw)
    {
        Base = Api.Normalize(raw);
        _api = null;
        Save();
    }

    public void SetUser(User u)
    {
        User = u;
        _api = null;
        Save();
    }

    public void SelectSource(string code)
    {
        SourceCode = code;
        Save();
    }
}
