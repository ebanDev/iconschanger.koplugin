# Icon Pack Changer Plugin for KOReader

This plugin allows you to change KOReader's icon pack by downloading icons from the Iconify API and applying custom icon mappings.

## Features

- Download icon packs from Iconify (200k+ icons from 150+ icon sets)
- **Custom local icons**: Store and use your own SVG icons directly in the plugin repository
- **Mixed icon packs**: Combine both local custom icons and Iconify icons in the same pack
- Backup and restore functionality for original icons
- Support for popular icon packs like Lucide, Feather, Heroicons, Material Design Icons, and many others
- Easy-to-use interface integrated into KOReader's menu system

## Installation

1. Copy the `iconschanger.koplugin` folder to your KOReader's `plugins` directory
2. Restart KOReader
3. The plugin will appear in the "More tools" menu as "Icon Pack Changer"

## Usage

### Basic Usage

1. **Download an Icon Pack:**
   - Go to Settings → More tools → Icon Pack Changer → Download Icon Pack
   - Enter the name of an icon pack (e.g., "lucide", "feather", "heroicons")
   - The plugin will automatically create a mapping between KOReader's current icons and the new pack

2. **Apply an Icon Pack:**
   - Go to Settings → More tools → Icon Pack Changer → Change Icon Pack
   - Select from your downloaded icon packs
   - Wait for the download and application process to complete
   - Restart KOReader to see the new icons

3. **Restore Original Icons:**
   - Go to Settings → More tools → Icon Pack Changer → Restore Original Icons
   - This will restore the original mdlight icons

### Popular Icon Packs

Here are some popular icon packs you can try:

- **lucide** - Beautiful, minimalist icons
- **phosphor** - Flexible icon family

### Custom Icon Mappings

You can create custom icon mappings by creating JSON files in the `iconpacks` directory. The plugin supports two types of icon sources:

#### 1. Iconify Icons (Downloaded from API)
Use the standard Iconify format for icons downloaded from the API:
```json
{
  "koreader_icon_name": "iconify_pack_icon_name",
  "wifi.open.0": "lucide-wifi-off",
  "appbar.search": "lucide-search",
  "home": "lucide-home"
}
```

#### 2. Local Custom Icons (Stored in Repository)
Use the `local:` prefix to reference SVG files stored in the `icons/` directory:
```json
{
  "koreader_icon_name": "local:subdirectory/icon_file.svg",
  "home": "local:custom-pack/home.svg",
  "appbar.search": "local:custom-pack/search.svg"
}
```

#### 3. Mixed Icon Packs
You can mix both local and Iconify icons in the same pack:
```json
{
  "home": "local:custom-pack/home.svg",
  "appbar.search": "lucide-search",
  "wifi.open.0": "local:custom-pack/wifi-off.svg",
  "appbar.settings": "lucide-settings"
}
```

To add custom icons:
1. Create a subdirectory in the `icons/` folder (e.g., `icons/my-custom-pack/`)
2. Add your SVG icon files to that directory
3. Create a JSON mapping file in `iconpacks/` that references your icons using the `local:` prefix
4. Add your icon pack to `config.json`

#### Step-by-Step Example

1. **Create the icon directory:**
   ```bash
   mkdir icons/my-pack
   ```

2. **Add your SVG files:**
   ```bash
   # Copy your custom SVG files to icons/my-pack/
   # For example: home.svg, search.svg, settings.svg
   ```

3. **Create the mapping file `iconpacks/my-pack.json`:**
   ```json
   {
     "home": "local:my-pack/home.svg",
     "appbar.search": "local:my-pack/search.svg", 
     "appbar.settings": "local:my-pack/settings.svg",
     "wifi.open.0": "lucide-wifi-off",
     "wifi.open.100": "lucide-wifi"
   }
   ```

4. **Add to `config.json`:**
   ```json
   {
     "display_name": "My Custom Pack",
     "path": "iconpacks/my-pack.json"
   }
   ```

#### Local vs Remote Icons

**Local Icons (`local:` prefix):**
- ✅ No internet connection required
- ✅ Faster application (no download needed)
- ✅ Perfect for custom designs or proprietary icons
- ✅ Full control over icon design and styling
- ❌ Manual color changes require editing SVG files

**Iconify Icons (no prefix):**
- ✅ Automatic color customization via plugin settings
- ✅ Access to 200k+ professionally designed icons
- ✅ Consistent icon families and styles
- ❌ Requires internet connection for initial download
- ❌ Limited to available Iconify icon sets

## How It Works

1. **Icon Discovery:** The plugin scans KOReader's current icon directory (`resources/icons/mdlight/`)
2. **Pack Analysis:** When applying a pack, it processes the icon mappings from JSON files
3. **Icon Processing:** 
   - For Iconify icons (no prefix): Downloads SVG files from Iconify's API with customizable colors
   - For local icons (`local:` prefix): Copies SVG files from the plugin's `icons/` directory
4. **Safe Application:** Icons are applied to the user's icon directory, leaving system icons untouched
5. **Backup Support:** Original icons can always be restored

## Iconify API

This plugin uses the [Iconify API](https://api.iconify.design) to:
- Get lists of available icons in icon packs
- Download individual SVG icons
- Access over 200,000 icons from 150+ open source icon sets

## Backup and Safety

- The plugin automatically creates a backup of your original icons before applying any changes
- You can always restore the original icons using the "Restore Original Icons" option
- Backups are stored in your KOReader settings directory under `iconschanger_backup`

## Troubleshooting

**Icons not appearing after restart:**
- Make sure you restarted KOReader completely
- Check that the icon files were properly downloaded to `resources/icons/mdlight/`

**Network errors during download:**
- Ensure you have an internet connection
- Try again as the Iconify API might be temporarily unavailable

**Icon pack not found:**
- Verify the icon pack name is correct
- Check the [Iconify website](https://iconify.design) for available icon sets

**Custom icons not working:**
- Use the included validation script: `python3 validate_icon_pack.py`
- Ensure local icon paths use forward slashes: `local:my-pack/icon.svg`
- Check that SVG files exist in the `icons/` directory
- Verify JSON syntax in your mapping files

**Some icons missing after applying pack:**
- Not all KOReader icons may have equivalents in every icon pack
- The original icon will remain if no suitable replacement is found

## Validation Tool

The plugin includes a validation script to help you check your custom icon packs:

```bash
# Validate all icon packs
python3 validate_icon_pack.py

# Validate a specific pack
python3 validate_icon_pack.py my-pack-name
```

The validator checks:
- JSON syntax and structure
- Local icon file existence
- Mapping format correctness
- Directory structure

## Contributing

To improve icon mappings for specific packs, you can:
1. Edit the mapping files in the `iconpacks` directory
2. Add new common mappings to the `findBestMatch` function in `main.lua`
3. Submit pull requests with improved mappings

## License

This plugin is released under the same license as KOReader (AGPL-3.0).

## Credits

- Uses the [Iconify API](https://iconify.design) for icon data and downloads
- Built for the [KOReader](https://koreader.rocks) e-book reader
- Inspired by the need for customizable UI theming in e-readers
