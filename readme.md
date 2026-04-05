# Triggrd

React to various system events by creating files with specific names.
## What's the fork?
This fork adds wifi and internet connectivity events: notifications when wifi signal strength changes, you connect/disconnect or switch networks, internet becomes reachable or unreachable (verified by active pings, not just route checks), and flap detection that alerts you when your connection is rapidly bouncing between up and down. The default automations directory has also been changed to `~/Triggrd-automations`. See the WiFi Events, Internet Reachability Events, and Ping Events sections below for details and configuration.

## Setup

* Triggrd is a spoon (plugin) for [Hammerspoon](https://hammerspoon.org). You will need to download and install it first. If you already have and use Hammerspoon, ignore the next step.
* Make sure you have a `.hammerspoon`directory in your home folder, and an `init.lua` file in it.
* Open `Triggrd.spoon` or copy it to `~/.hammerspoon/spoons/`
* Somewhere within your `init.lua` file, add the following lines:
```lua
hs.loadSpoon("Triggrd")
spoon.Triggrd:start()
````
* There is a set of example event automations in the *My Example Triggrd Automations* directory in this repository. Copy or symlink its contents into `~/Triggrd-automations` (or your configured automations path).

### Migrating from SoundNote

Triggrd includes a utility to migrate SoundNote soundpacks to the Triggrd format. To access it, click on the Triggrd menu on the menu bar and select "Migrate SoundNote soundpack..."

Note for blind users: The Triggrd menu in menu extras is spoken as "Hammerspoon: Triggrd". There seems to be nothing I can do about that for now.

## Basic concepts

* All of your automations will be in a path of your choosing. By default, this is `~/Triggrd-automations`. You can change this by modifying the `userAutomationsPath` variable in the spoon's `init.lua`.
* Any file or folder in the automations directory whose name *beginns with a dot (.)* will be ignored by Triggrd.
* Every event is composed of several *tags*. To react to an event, you can create a file in the automations directory or any of its subdirectories with a name composed of tags separated by dots (.). The list of supported extensions is down below. For example, `app.launched.wav`, `battery.20percent.down.lua`, or `power.txt`.
* An automation will only trigger if the event contains *all* of its tags. `volume.wav` will play every time any event happens with any volume, `app.launched.Safari` will trigger when Safari is launched, `battery.40percent.txt` will be spoken when the battery reaches 40% either charging or discharging.

## Supported file types

* Audio files: Any file format supported by `hs.sound`.
* Lua scripts: They will receive an event data table as a vararg which will contain, at the very least, a reference to the `Triggrd` object.
* TXT files: They will be spoken by the default system voice. Some of them may let you use formatstrings to add relevant data into the spoken text.

## Supported events

### Application events (app)

All of these events will include a tag with the name of the app in question.

TXT files may also reference two formatstring arguments, the name of the app and the event type.

* `activated` (gets focus)
* `deactivated` (loses focus)
* `hidden`
* `unhidden`
* `launching`
* `launched`
* `terminated` (quit)

### Screen and system power states (caff)

TXT files may also reference a single formatstring argument, the event type.

* `screensaverDidStart`
* `screensaverWillStop`
* `screensaverDidStop`
* `screensDidLock`
* `screensDidUnlock`
* `screensDidWake`
* `screensDidSleep`
* `sessionDidBecomeActive`
* `sessionDidResignActive`
* `systemWillSleep`
* `systemDidWake`
* `systemWillPowerOff`

### USB Events (usb)

All of these events will include a tag with the name of the USB device in question.

TXT files may also reference two formatstring arguments, the name of the device and the event type.

* `added` (connected)
* `removed` (disconnected)

### Space Change Event (spacechange)

The second tag may be the word space followed by the number of the new space. This number will also be passed as a formatstring argument to txt files.

### Pasteboard Change Event (pasteboard)

The second tag may be the contents of the pasteboard. These will also be passed as a formatstring to txt files.

### Battery Events (battery)

* xpercent, where x is a battery percentage
* up, when the change in percentage is upwards
* down, for the opposite
* charging, for when the battery starts charging. Will not include percentage tags
* notCharging, for the opposite

### Power source change events (power)

* `onAC`
* `onBattery`
* `offLine`

### Screen Change Event (screenchanged)

This event seems to fire whenever a change occurs in the screen configuration or layout.

### WiFi Events (wifi)

#### connect

Fires when wifi connects to a network from a disconnected state. Includes a tag with the network name.

TXT files may reference one formatstring argument: the network name.

* `wifi.connect.<networkName>` - connected to a specific network

#### disconnect

Fires when wifi disconnects from a network.

TXT files may reference one formatstring argument: the interface name.

#### SSIDChange

Fires when switching from one network to another (already connected). Includes a tag with the new network name.

TXT files may reference one formatstring argument: the new network name.

* `wifi.SSIDChange.<networkName>` - switched to a specific network

#### BSSIDChange

Fires when the base station (access point) changes.

TXT files may reference one formatstring argument: the BSSID.

#### countryCodeChange

Fires when the wifi country code changes. Includes a tag with the new country code.

TXT files may reference one formatstring argument: the country code.

#### linkQualityChange

Fires when the signal quality changes. Includes an RSSI tag using the absolute value of the RSSI (e.g. `rssi65` for an RSSI of -65), plus `up` or `down` tags indicating direction of change.

TXT files may reference two formatstring arguments: the RSSI value and the transmit rate.

* `wifi.linkQualityChange.rssi65` - signal at exactly -65 dBm
* `wifi.linkQualityChange.down` - signal got weaker
* `wifi.linkQualityChange.up` - signal got stronger

#### modeChange

Fires when the wifi operating mode changes.

TXT files may reference one formatstring argument: the interface name.

#### powerChange

Fires when wifi is turned on or off. Includes a tag for the power state.

TXT files may reference one formatstring argument: the power state.

* `wifi.powerChange.powerOn`
* `wifi.powerChange.powerOff`

#### scanCacheUpdated

Fires when the wifi scan cache is updated. Note: this event may fire frequently.

TXT files may reference one formatstring argument: the interface name.

### Internet Reachability Events (internet)

Monitors internet connectivity using two layers:

1. **Passive route detection** — uses `hs.network.reachability.internet()` to instantly detect when network interfaces go up or down (IPv4 and IPv6).
2. **Active ping verification** — periodically pings known public DNS servers to detect actual packet loss, even when the route still exists (e.g. flaky wifi, ISP outage).

The ping interval adapts automatically: when pings fail, it drops to the minimum interval immediately for fast detection. When pings succeed, the interval gradually doubles back up to the maximum.

#### Configuration

These can be set in `init.lua`:

| Variable | Default | Description |
|---|---|---|
| `pingTargetsV4` | `{"1.1.1.1", "9.9.9.9"}` | IPv4 addresses to ping |
| `pingTargetsV6` | `{"2606:4700:4700::1111", "2620:fe::fe"}` | IPv6 addresses to ping (only used when a v6 route exists) |
| `pingMaxInterval` | `60` | Seconds between pings when connection is stable |
| `pingMinInterval` | `3` | Fastest ping rate when connection is degraded |
| `pingConfirmThreshold` | `2` | Consecutive failures (or successes) required before changing state |
| `flapWindow` | `600` | Seconds to look back for state transitions |
| `flapThreshold` | `4` | Transitions in window to trigger flapping (4 = two full down/up cycles) |
| `flapReminderMax` | `300` | Max seconds between repeated flapping reminders |

#### internet.reachable

Fires when internet connectivity is confirmed after being unreachable. Requires `pingConfirmThreshold` consecutive successful pings.

#### internet.unreachable

Fires when internet connectivity is lost. This can happen instantly (route down) or after `pingConfirmThreshold` consecutive failed pings.

Note: `internet.reachable` and `internet.unreachable` fire independently of flap detection. Users can choose which automations to create based on what feedback they want.

#### internet.flapping

Fires when the connection is rapidly toggling between reachable and unreachable (`flapThreshold` transitions within `flapWindow` seconds). On first detection, fires immediately. If still flapping, fires escalating reminders starting at the lesser of `flapWindow` or `flapReminderMax`, then doubling each time up to `flapReminderMax`.

TXT files may reference one formatstring argument: the number of transitions in the window.

#### internet.stable

Fires when a flapping episode ends and the connection is confirmed online (route exists and pings succeeding). If flapping ends because the connection went fully offline, this event is suppressed — `internet.unreachable` already covers that case.

### Ping Events (ping)

Individual ping results, fired on every check cycle. Useful for audible feedback while connectivity is degraded.

#### ping.success

Fires when a ping check succeeds. Includes a tag with the address that responded (e.g. `{"ping", "success", "1.1.1.1"}`).

TXT files may reference one formatstring argument: the address that responded.

* `ping.success.1.1.1.1` - specifically 1.1.1.1 responded

#### ping.fail

Fires when all ping targets fail in a check cycle. Includes tags for each target that was tried.

TXT files may reference one formatstring argument: the consecutive failure count.

### Volume Events (volume)

* `didMount`
* `willUnmount`
* `didUnmount`
* `didRename`

## Plans

The "roadmap" is "detailed" [here](tasks.md). Any suggestions and/or pull requests are welcome.

## Acknowledgments

* @GRMrGecko for creating [SoundNote](https://github.com/GRMrGecko/SoundNote), which became an invaluable tool for me and many other blind mac users and inspired Triggrd.
* @Mikholysz for writing the first few lines of code, and finally getting me to work on this.
* My good friends of [Currently Untitled Audio](https://currentlyuntitledaudio.design) for the example set, which we will be expanding as new events come in.
