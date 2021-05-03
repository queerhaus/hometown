# Queer Haus Hometown

This is a fork of [Hometown](https://github.com/hometown-fork/hometown) which is a fork of [Mastodon](https://github.com/tootsuite/mastodon).

This repo is not intended to be used by others as it contains specific changes to our instance. 
We try to contribute back to the upstream projects whenever we can.


## Local development environment

Hometown comes with a preconfigured local environment using docker. 

1. Install Docker https://www.docker.com/products/docker-desktop
2. Make sure that docker is correctly set up in your environment. This command should print an empty list of containers that are running:<br>
  `$ docker ps`<br>
  If that gives you an error, resolve that using standard Docker guides _before continuing_.

3. Initialize the project by installing dependencies and creating the database<br>
    `$ make init`<br>
    This can take up to 30 minutes depending on your machine, be patient. You should see lots of output as it goes through these steps: docker image build, bundle install, yarn install, database setup<br>
    The output will pause at some points. If you wonder what docker is doing, open a new terminal and run this handy command:<br>
    `docker stats`

4. Start the containers<br>
  `$ make up`<br>
   Wait until webpack has compiled all resources, takes a minute or two.

6. Then you can access Hometown on http://localhost:3000

7. Press CTRL-C to stop the services.

8. To start it again next time, run this command and all dependencies are updated and containers rebuilt as needed.<br>
`$ make up`


## License

Copyright (C) 2016-2020 Eugen Rochko & other Mastodon contributors (see [AUTHORS.md](AUTHORS.md))

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
