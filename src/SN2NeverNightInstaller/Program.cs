using Microsoft.Win32;
using System.Reflection;
using System.Text;

namespace SN2NeverNightInstaller;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm());
    }
}

internal sealed class InstallerForm : Form
{
    private readonly TextBox gamePathBox = new() { Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top, ReadOnly = false };
    private readonly Label statusLabel = new() { Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom, AutoSize = false, Height = 76 };
    private readonly Button browseButton = new() { Text = "Change..." };
    private readonly Button detectButton = new() { Text = "Detect again" };
    private readonly Button installButton = new() { Text = "Install / Update" };
    private readonly Button disableButton = new() { Text = "Disable" };
    private readonly Button openFolderButton = new() { Text = "Open folder" };

    public InstallerForm()
    {
        Text = "Subnautica 2 NeverNight Installer";
        MinimumSize = new Size(720, 430);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10f);

        var title = new Label
        {
            Text = "Subnautica 2 NeverNight",
            Font = new Font(Font, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(24, 22)
        };

        var description = new Label
        {
            Text = "Installs the source-only UE4SS Lua mod. No game files are modified except ue4ss\\Mods and mods.txt.",
            AutoSize = true,
            Location = new Point(24, 56)
        };

        var pathLabel = new Label
        {
            Text = "Detected game folder:",
            AutoSize = true,
            Location = new Point(24, 102)
        };

        gamePathBox.Location = new Point(24, 128);
        gamePathBox.Width = 540;
        gamePathBox.TextChanged += (_, _) => RefreshState();

        browseButton.Location = new Point(578, 126);
        browseButton.Width = 100;
        browseButton.Click += (_, _) => BrowseForGameFolder();

        detectButton.Location = new Point(24, 172);
        detectButton.Width = 120;
        detectButton.Click += (_, _) => DetectGamePath(showSuccess: true);

        installButton.Location = new Point(160, 172);
        installButton.Width = 140;
        installButton.Click += (_, _) => InstallMod();

        disableButton.Location = new Point(316, 172);
        disableButton.Width = 100;
        disableButton.Click += (_, _) => DisableMod();

        openFolderButton.Location = new Point(432, 172);
        openFolderButton.Width = 110;
        openFolderButton.Click += (_, _) => OpenGameFolder();

        var commands = new Label
        {
            Text = "Commands after install: day, stats, stats_100, sn2_stats, survival_guard_10s, sn2_help",
            AutoSize = true,
            Location = new Point(24, 230)
        };

        var note = new Label
        {
            Text = "UE4SS is required. If UE4SS is missing, install UE4SS for Subnautica 2 first, then run this installer again.",
            AutoSize = true,
            Location = new Point(24, 260)
        };

        statusLabel.Location = new Point(24, 312);
        statusLabel.Width = 650;
        statusLabel.Text = "Detecting Subnautica 2...";

        Controls.AddRange(new Control[]
        {
            title, description, pathLabel, gamePathBox, browseButton, detectButton,
            installButton, disableButton, openFolderButton, commands, note, statusLabel
        });

        DetectGamePath(showSuccess: false);
    }

    private void DetectGamePath(bool showSuccess)
    {
        var detected = SteamLocator.FindSubnautica2Install();
        if (detected is null)
        {
            SetStatus("Could not auto-detect Subnautica 2. Use Change... and select the Subnautica2 folder from Steam.", isError: true);
            gamePathBox.Text = string.Empty;
            RefreshState();
            return;
        }

        gamePathBox.Text = detected;
        RefreshState();
        if (showSuccess)
        {
            SetStatus("Detected Subnautica 2.", isError: false);
        }
    }

    private void BrowseForGameFolder()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Select the Subnautica2 game folder, not Binaries\\Win64.",
            UseDescriptionForTitle = true,
            SelectedPath = Directory.Exists(gamePathBox.Text) ? gamePathBox.Text : Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            gamePathBox.Text = dialog.SelectedPath;
        }
    }

    private void InstallMod()
    {
        try
        {
            var layout = GameLayout.FromGameRoot(gamePathBox.Text);
            if (!layout.IsGameRootValid)
            {
                SetStatus("That folder does not look like Subnautica 2. Select the folder that contains Subnautica2\\Binaries\\Win64.", isError: true);
                return;
            }

            if (!layout.IsUe4ssInstalled)
            {
                SetStatus("UE4SS is not installed in Binaries\\Win64. Install UE4SS for Subnautica 2 first, then run this installer again.", isError: true);
                return;
            }

            Directory.CreateDirectory(layout.ModScriptsDirectory);
            File.WriteAllText(Path.Combine(layout.ModScriptsDirectory, "main.lua"), EmbeddedFiles.ReadNeverNightLua(), new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
            ModsTxt.EnsureEnabled(layout.ModsTxtPath, "NeverNight");

            SetStatus("Installed NeverNight. Launch or reload UE4SS, then use console command: day. For emergency stats: stats or stats_100.", isError: false);
        }
        catch (Exception ex)
        {
            SetStatus("Install failed: " + ex.Message, isError: true);
        }
    }

    private void DisableMod()
    {
        try
        {
            var layout = GameLayout.FromGameRoot(gamePathBox.Text);
            if (!File.Exists(layout.ModsTxtPath))
            {
                SetStatus("Could not find ue4ss\\Mods\\mods.txt.", isError: true);
                return;
            }

            ModsTxt.SetEnabled(layout.ModsTxtPath, "NeverNight", enabled: false);
            SetStatus("Disabled NeverNight in mods.txt. The mod folder remains on disk so it can be re-enabled later.", isError: false);
        }
        catch (Exception ex)
        {
            SetStatus("Disable failed: " + ex.Message, isError: true);
        }
    }

    private void OpenGameFolder()
    {
        if (!Directory.Exists(gamePathBox.Text))
        {
            SetStatus("Folder does not exist.", isError: true);
            return;
        }

        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = gamePathBox.Text,
            UseShellExecute = true
        });
    }

    private void RefreshState()
    {
        var layout = GameLayout.FromGameRoot(gamePathBox.Text);
        installButton.Enabled = layout.IsGameRootValid;
        disableButton.Enabled = File.Exists(layout.ModsTxtPath);
        openFolderButton.Enabled = Directory.Exists(gamePathBox.Text);

        if (string.IsNullOrWhiteSpace(gamePathBox.Text))
        {
            return;
        }

        if (!layout.IsGameRootValid)
        {
            SetStatus("Waiting for a valid Subnautica 2 game folder.", isError: true);
        }
        else if (!layout.IsUe4ssInstalled)
        {
            SetStatus("Game found. UE4SS is missing from Binaries\\Win64.", isError: true);
        }
        else
        {
            SetStatus("Game and UE4SS found. Ready to install/update.", isError: false);
        }
    }

    private void SetStatus(string message, bool isError)
    {
        statusLabel.Text = message;
        statusLabel.ForeColor = isError ? Color.DarkRed : Color.DarkGreen;
    }
}

internal sealed record GameLayout(string GameRoot)
{
    public string Win64Directory => Path.Combine(GameRoot, "Subnautica2", "Binaries", "Win64");
    public string ShippingExe => Path.Combine(Win64Directory, "Subnautica2-Win64-Shipping.exe");
    public string Ue4ssDirectory => Path.Combine(Win64Directory, "ue4ss");
    public string ModsDirectory => Path.Combine(Ue4ssDirectory, "Mods");
    public string ModsTxtPath => Path.Combine(ModsDirectory, "mods.txt");
    public string ModScriptsDirectory => Path.Combine(ModsDirectory, "NeverNight", "Scripts");
    public bool IsGameRootValid => File.Exists(ShippingExe);
    public bool IsUe4ssInstalled => File.Exists(Path.Combine(Win64Directory, "dwmapi.dll")) && File.Exists(Path.Combine(Ue4ssDirectory, "UE4SS.dll")) && Directory.Exists(ModsDirectory);

    public static GameLayout FromGameRoot(string? gameRoot) => new(string.IsNullOrWhiteSpace(gameRoot) ? string.Empty : gameRoot.Trim());
}

internal static class SteamLocator
{
    public static string? FindSubnautica2Install()
    {
        foreach (var library in FindSteamLibraries().Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var manifest = Path.Combine(library, "steamapps", "appmanifest_1962700.acf");
            if (!File.Exists(manifest))
            {
                continue;
            }

            var installDir = ReadAcfValue(manifest, "installdir") ?? "Subnautica2";
            var candidate = Path.Combine(library, "steamapps", "common", installDir);
            if (GameLayout.FromGameRoot(candidate).IsGameRootValid)
            {
                return candidate;
            }
        }

        return null;
    }

    private static IEnumerable<string> FindSteamLibraries()
    {
        var steamPath = ReadSteamPathFromRegistry();
        if (!string.IsNullOrWhiteSpace(steamPath))
        {
            yield return steamPath;
            foreach (var library in ReadLibraryFolders(steamPath))
            {
                yield return library;
            }
        }

        var defaultPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Steam");
        if (Directory.Exists(defaultPath))
        {
            yield return defaultPath;
            foreach (var library in ReadLibraryFolders(defaultPath))
            {
                yield return library;
            }
        }
    }

    private static string? ReadSteamPathFromRegistry()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam");
            return key?.GetValue("SteamPath") as string;
        }
        catch
        {
            return null;
        }
    }

    private static IEnumerable<string> ReadLibraryFolders(string steamRoot)
    {
        var vdf = Path.Combine(steamRoot, "steamapps", "libraryfolders.vdf");
        if (!File.Exists(vdf))
        {
            yield break;
        }

        foreach (var line in File.ReadLines(vdf))
        {
            var trimmed = line.Trim();
            if (!trimmed.Contains("\"path\"", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var value = ExtractSecondQuotedValue(trimmed);
            if (!string.IsNullOrWhiteSpace(value) && Directory.Exists(value))
            {
                yield return value.Replace("\\\\", "\\");
            }
        }
    }

    private static string? ReadAcfValue(string path, string key)
    {
        foreach (var line in File.ReadLines(path))
        {
            var trimmed = line.Trim();
            if (!trimmed.StartsWith("\"" + key + "\"", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            return ExtractSecondQuotedValue(trimmed);
        }

        return null;
    }

    private static string? ExtractSecondQuotedValue(string line)
    {
        var values = new List<string>();
        var start = -1;
        for (var index = 0; index < line.Length; index++)
        {
            if (line[index] != '"')
            {
                continue;
            }

            if (start < 0)
            {
                start = index + 1;
            }
            else
            {
                values.Add(line[start..index]);
                start = -1;
            }
        }

        return values.Count >= 2 ? values[1] : null;
    }
}

internal static class ModsTxt
{
    public static void EnsureEnabled(string path, string modName)
    {
        SetEnabled(path, modName, enabled: true);
    }

    public static void SetEnabled(string path, string modName, bool enabled)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var desired = modName + " : " + (enabled ? "1" : "0");
        var lines = File.Exists(path) ? File.ReadAllLines(path).ToList() : new List<string>();
        var index = lines.FindIndex(line => line.TrimStart().StartsWith(modName + " :", StringComparison.OrdinalIgnoreCase));

        if (index >= 0)
        {
            lines[index] = desired;
        }
        else
        {
            var keybindIndex = lines.FindIndex(line => line.TrimStart().StartsWith("Keybinds :", StringComparison.OrdinalIgnoreCase));
            if (keybindIndex >= 0)
            {
                lines.Insert(keybindIndex, desired);
            }
            else
            {
                lines.Add(desired);
            }
        }

        File.WriteAllLines(path, lines, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
    }
}

internal static class EmbeddedFiles
{
    public static string ReadNeverNightLua()
    {
        var assembly = Assembly.GetExecutingAssembly();
        using var stream = assembly.GetManifestResourceStream("NeverNight.Scripts.main.lua")
            ?? throw new InvalidOperationException("Embedded Lua mod was not found.");
        using var reader = new StreamReader(stream, Encoding.UTF8);
        return reader.ReadToEnd();
    }
}
