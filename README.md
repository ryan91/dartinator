# Dartinator

## Introduction

Have you every played darts and were like "well this is not as cool as the pros
in the Ally Pally at all - I even have to calculate my own score and not even
De Sousa can do that!"? Well this is the app for you! The idea behind the
Dartinator is for you to have your score show on a big monitor while you type
the fields you hit on your smart phone or a tablet. No need to keep track of
your score manually and not as much calculating. A little bit of Ally Pally
wherever you play!

## Idea behind the application

Our suggestion is to run the application on a Raspberry PI or something
similarly small that fits nicely into your room. However, it can absolutely run
on a PC as well. The software consists of three parts:

### The client side

The client can connect to the Dartinator server and add users, then start a new
game of his choice. Once the game has started, the client is shown a dartboard
on which he can register the fields that are being hit.

### The view side

Ideally, the device running the server is connected to a big monitor where you
can start up a browser and see the score live.

## Installation

### Dependencies

Dartinator depends on the following libraries and applications:

* PostgreSQL (min. Version 9) - as a database backend
* Python (min. Version 3) - for the server
* Pip (python's package manager, should come with the python installation)
* Any Web browser (tested with Firefox, but anything not too obscure should
  work)

### Setup Dartinator

#### Clone this git

```
git clone <url from green 'code' button on hithub> <dartinator_root>
```

`<dartinator_root>` is the directory where you want to download the program.

#### PostgreSQL

First, we will set up the database. Usually, when installing PostgreSQL, the
installer will add a user `postgres` who is the administrator. Assuming you
have `sudo` privileges, you can change to this user with `sudo -su postgres`.
As this user, go over the following steps

1. Create a database cluster

This is where PostgreSQL stores the data. This directory is referred to as
`<cluster_dir>` in the following steps. To create a new cluster, run

```
initdb --locale en_US.UTF-8 -D <cluster_dir>
```

2. Start the PostgreSQL service

```
pg_ctl -D <cluster_dir> start
```

It should say something like 'server started', if everything goes fine.
In case it says 'could not create lock file' - this is often because the
`postgres` user does not have sufficient rights to create the folder in which he
tries to create the lock file. In this case just create the folder `mkdir
<folder>` and give it to the user `chown -R postgres:postgres <folder>`.

3. Add a user

You should now first create a user named `dartinator`.

```
createuser --interactive
Enter name of role to add: dartinator
Shall the new role be a superuser? (y/n) n
Shall the new role be allowed to create databases? (y/n) n
Shall the new role be allowed to create more roles? (y/n) n
```

4. Crate a database

Now, you'll set up a database which is also named `dartinator`.

```
createdb dartinator
```

5. Change the owner owner of the database to `dartinator`

```
psql -c "alter database dartinator owner to dartinator;"
```

And that's is for PostgreSQL!

#### Set up the databases

Next, you switch to another directory (`cd <dartinator_root>`) and you will
source the SQL files that create the tables and functions for _dartinator_ like:

```
psql -d dartinator -U dartinator < dartinator/postgresql/tables.sql
psql -d dartinator -U dartinator < dartinator/postgresql/functions.sql
```

#### Install Python packages

Create a virtual environment

```
virtualenv .venv
```

Enter the virtual environment

```
source .venv/bin/activate
```

Install the packages and _dartinator_


```
python -m pip install -e .
```

#### Start the server

```
FLASK_APP=__init__.py flask run
```

If the server is running, you should be able to access `localhost:5000` in your
Browser and it provides you with _dartinator_'s main menu.
