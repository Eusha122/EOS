# Void

Void is EOS Privet's privacy-browser product.

## First implementation

The first image uses Debian's `torbrowser-launcher` to download and run upstream Tor Browser. The small `void-browser` launcher gives EOS Privet a stable name and future package boundary without altering Tor Browser's privacy-sensitive internals.

On a fresh session, the downloaded Tor Browser data remains temporary. When encrypted saved storage is implemented, only its approved profile data will be available after the user unlocks the EOS USB.

## Important limit

Void provides a Tor-native browser path. It does not make every app or every network action anonymous, and users must not treat it as a guarantee of safety or invisibility.
