# Gleam Postgres Starter with Mist

This is a simple, basic Gleam mist application, each request adds an entry with a UUID(using gluid) to the PostgreSQL database and returns a count.

## Something you should know

- Gluid - for generating uuids
- Glenvy - used for accessing `.env` so that we can connect to db. I didnt use Envoy as it doesnt access my `.env` but access my shell environment so to connect i hade to use `export DATABASE_URL=url` Lol
- Mist - oh my a misty web server UwU

## Development

```sh
gleam build # Builds the project
gleam run   # Run the project
```

## Deploying

you can use `zerops-project-import.yml` from the codebase to import this project to your zerops dashboard.


This is my first gleam code i wrote while taking some help from their discord server and making silly dumb mistakes DIDNT KNOW WHAT I WAS DOING AT FIRST. Also going through the packages docs on Hex hahaha.