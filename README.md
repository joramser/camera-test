# Camera Test

Camera Test is an Omarchy Shell bar widget for previewing and verifying connected cameras.

## Features

- Live camera preview from the Omarchy bar
- Switching between connected cameras with the panel controls or arrow keys
- Mirrored preview toggle
- Preferred-camera selection by matching part of the device name
- Live frame and camera error status
- Cleaner display names for UVC devices that repeat their product name

## Install

```bash
omarchy plugin add https://github.com/joramser/camera-test.git --enable --yes
```

The widget defaults to the right section of the bar. Click the camera icon to open or close the preview.

## Remove

```bash
omarchy plugin remove joramser.camera-test --yes
```

## Requirements And Privacy

Camera Test requires Omarchy Shell and Qt Multimedia, both provided by Omarchy. It has no additional package, service, network, installer, or elevated-privilege requirements.

The plugin accesses the camera selected through Qt Multimedia while its panel is open. It does not record, save, or transmit camera frames. Closing the panel destroys the capture pipeline and releases the camera device.

## Development

Validate the plugin from its repository root:

```bash
omarchy plugin validate .
```

For local development, link the repository into Omarchy's plugin directory and restart the shell:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/joramser.camera-test
omarchy plugin enable joramser.camera-test --section right
omarchy restart shell
```

## License

[MIT](LICENSE)
