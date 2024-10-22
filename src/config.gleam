import gleam/pgo
import gleam/io
import glenvy/dotenv
import glenvy/env

pub fn get_db_connection() -> Result(pgo.Connection, Nil) {
  case dotenv.load() {
    Ok(_) -> io.println("Environment variables loaded successfully")
    Error(_) -> io.println("Warning: Could not load .env file")
  }
  
  case env.get_string("DATABASE_URL") {
    Ok(database_url) -> {
      case pgo.url_config(database_url) {
        Ok(config) -> {
          let connection = pgo.connect(config)
          io.println("Successfully connected to database! ✨")
          Ok(connection)
        }
        Error(_) -> {
          io.println("Failed to parse database configuration")
          Error(Nil)
        }
      }
    }
    Error(_) -> {
      io.println("Failed to get DATABASE_URL from environment")
      Error(Nil)
    }
  }
}