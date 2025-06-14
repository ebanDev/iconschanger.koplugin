# Icon Pack Changer Plugin for KOReader

This plugin allows you to change KOReader's icon pack by downloading icons from the Iconify API and applying custom icon mappings.

## Features

- Download icon packs from Iconify (200k+ icons from 150+ icon sets)
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

You can create custom icon mappings by creating JSON files in the `iconpacks` directory. The format is:

```json
{
  "koreader_icon_name": "new_icon_pack_icon_name",
  "wifi.open.0": "wifi-off",
  "appbar.search": "search",
  "home": "home"
}
```

## How It Works

1. **Icon Discovery:** The plugin scans KOReader's current icon directory (`resources/icons/mdlight/`)
2. **Pack Analysis:** When downloading a pack, it fetches the icon list from Iconify's API
3. **Safe Application:** Original icons are backed up before applying new ones
4. **SVG Download:** Individual icons are downloaded from Iconify's API as SVG files

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

**Some icons missing after applying pack:**
- Not all KOReader icons may have equivalents in every icon pack
- The original icon will remain if no suitable replacement is found

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
