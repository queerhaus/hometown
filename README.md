# Queer Haus Hometown

This is a fork of [Hometown](https://github.com/hometown-fork/hometown) which is a fork of [Mastodon](https://github.com/tootsuite/mastodon).

This repo is not intended to be used by others as it contains specific changes to our instance. 
We try to contribute back to the upstream projects whenever we can.


## Local development environment

Queer Haus comes with a preconfigured local environment using docker.

### Prerequisites
1. Install make<br>
   Mac: `brew install make`<br>
   Ubuntu: `sudo apt install make`<br>
   Windows: https://stackoverflow.com/questions/32127524/how-to-install-and-use-make-in-windows

2. Install Docker<br>
   Ubuntu: https://docs.docker.com/engine/install/ubuntu/<br>
   Mac/Windows: https://www.docker.com/products/docker-desktop

3. Make sure that docker is correctly set up in your environment.
   This command should print an empty list of containers that are running:<br>
   `$ docker ps`<br>
   If that command gives you an error, resolve that using standard Docker guides _before continuing_. 
   The command should not require sudo, if it does, your setup is not working correctly.

### Usage

1. Initialize the project and start the containers<br>
  `$ make up`<br>
   The first time this build can take up to 30 minutes depending on your machine.
   Wait until all services has started and webpack says it has compiled all resources.

2. Then you can access Queer Haus on http://localhost:3000

3. Press CTRL-C to stop the services.

4. To start it again next time, run the same command. 
   Dependencies are updated and containers rebuilt as needed.<br>
   `$ make up`

5. Want to start over with a clean dev environment? 
   Run 'clean' to stop everything and delete all databases.<br>
   `$ make clean`


## License

Copyright (C) 2016-2020 Eugen Rochko & other Mastodon contributors (see [AUTHORS.md](AUTHORS.md))

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
