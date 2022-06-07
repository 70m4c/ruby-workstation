# Ruby Workstation

Ruby Workstation is an [Arch Linux](https://archlinux.org) installation script that creates a development environment for [Ruby](https://www.ruby-lang.org).

## Usage

The following steps will install Ruby Workstation.

1. Boot a recent Arch Linux installation image.

2. Retrieve the contents of this repository using the following command.

```sh
curl -sSL https://github.com/70m4c/ruby-workstation/archive/refs/heads/master.tar.gz | tar xz --strip-components=1
```

3. Customize the `install.sh`, `packages`, `mirrorlist` and other files to suit your needs.

4. Run the installation script.

```sh
bash install.sh
```

5. Reboot.

## Copyright & License

Copyright ©2022 Томас

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/gpl-3.0.html>.