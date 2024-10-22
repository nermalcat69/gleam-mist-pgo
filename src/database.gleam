import gleam/string
import gleam/pgo
import gleam/io
import gleam/dynamic
import gleam/int
import gluid

pub fn table(conn: pgo.Connection) -> Result(Nil, String) {
  let check_table_query = "
    SELECT EXISTS (
      SELECT FROM pg_tables 
      WHERE schemaname = 'public' 
      AND tablename = 'entries'
    );
  "
  
  case pgo.execute(
    query: check_table_query,
    on: conn,
    with: [],
    expecting: fn(row) { 
      dynamic.element(0, dynamic.bool)(row)
    }
  ) {
    Ok(result) -> {
      case result.rows {
        [exists] -> {
          case exists {
            True -> add_uuid_column_if_missing(conn)
            False -> create_new_table(conn)
          }
        }
        _ -> Error("Unexpected result checking table existence")
      }
    }
    Error(err) -> {
      let error_message = query_error_to_string(err)
      Error("Failed to check table existence: " <> error_message)
    }
  }
}

fn create_new_table(conn: pgo.Connection) -> Result(Nil, String) {
  let create_table_query = "
    CREATE TABLE entries (
      id SERIAL PRIMARY KEY,
      uuid TEXT NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
  "
  io.println("Creating new entries table...")
  
  case pgo.execute(
    query: create_table_query,
    on: conn,
    with: [],
    expecting: dynamic.dynamic
  ) {
    Ok(_) -> {
      io.println("Table entries created successfully")
      Ok(Nil)
    }
    Error(err) -> {
      let error_message = query_error_to_string(err)
      Error("Failed to create table: " <> error_message)
    }
  }
}

fn add_uuid_column_if_missing(conn: pgo.Connection) -> Result(Nil, String) {
  let check_column_query = "
    SELECT EXISTS (
      SELECT FROM information_schema.columns 
      WHERE table_name = 'entries' 
      AND column_name = 'uuid'
    );
  "
  
  case pgo.execute(
    query: check_column_query,
    on: conn,
    with: [],
    expecting: fn(row) {
      dynamic.element(0, dynamic.bool)(row)
    }
  ) {
    Ok(result) -> {
      case result.rows {
        [exists] -> {
          case exists {
            False -> {
              let add_column_query = "
                ALTER TABLE entries 
                ADD COLUMN uuid TEXT NOT NULL DEFAULT '';
              "
              io.println("Adding uuid column to existing table...")
              
              case pgo.execute(
                query: add_column_query,
                on: conn,
                with: [],
                expecting: dynamic.dynamic
              ) {
                Ok(_) -> {
                  io.println("UUID column added successfully")
                  Ok(Nil)
                }
                Error(err) -> {
                  let error_message = query_error_to_string(err)
                  Error("Failed to add uuid column: " <> error_message)
                }
              }
            }
            True -> {
              io.println("UUID column already exists")
              Ok(Nil)
            }
          }
        }
        _ -> Error("Unexpected result checking column existence")
      }
    }
    Error(err) -> {
      let error_message = query_error_to_string(err)
      Error("Failed to check column existence: " <> error_message)
    }
  }
}

pub fn get_all_entries(conn: pgo.Connection) -> Result(List(#(String, String)), String) {
  let query = "
    SELECT uuid, created_at::text 
    FROM entries 
    ORDER BY created_at DESC 
    LIMIT 5"
  
  case pgo.execute(
    query: query,
    on: conn,
    with: [],
    expecting: fn(row) -> Result(#(String, String), List(dynamic.DecodeError)) {
      case 
        dynamic.tuple2(
          dynamic.string,
          dynamic.string
        )(row) {
          Ok(#(uuid, timestamp)) -> Ok(#(uuid, timestamp))
          Error(errs) -> Error(errs)
      }
    }
  ) {
    Ok(result) -> Ok(result.rows)
    Error(err) -> {
      let error_message = query_error_to_string(err)
      Error("Failed to get entries: " <> error_message)
    }
  }
}

pub fn add_entry_and_get_count(conn: pgo.Connection) -> Result(#(String, Int), String) {
  io.println("Adding entry and getting count")
  case table(conn) {
    Ok(_) -> {
      let uuid = gluid.guidv4()
      io.println("Generated UUID: " <> uuid)
      
      let insert_query = "INSERT INTO entries (uuid) VALUES ($1)"
      io.println("Executing insert query with UUID")
      
      case pgo.execute(
        query: insert_query,
        on: conn,
        with: [pgo.text(uuid)],
        expecting: dynamic.dynamic
      ) {
        Ok(_) -> {
          io.println("Entry added successfully")
          case get_count(conn) {
            Ok(count) -> Ok(#(uuid, count))
            Error(err) -> Error(err)
          }
        }
        Error(err) -> {
          let error_message = query_error_to_string(err)
          io.println("Failed to add entry: " <> error_message)
          Error("Failed to add entry: " <> error_message)
        }
      }
    }
    Error(err) -> {
      io.println("Failed to ensure table exists: " <> err)
      Error("Failed to ensure table exists: " <> err)
    }
  }
}

fn get_count(conn: pgo.Connection) -> Result(Int, String) {
  let count_query = "SELECT COUNT(*) FROM entries"
  io.println("Executing count query: " <> count_query)
  case pgo.execute(
    query: count_query,
    on: conn,
    with: [],
    expecting: fn(row) {
      dynamic.element(0, dynamic.int)(row)
    }
  ) {
    Ok(result) -> {
      case result.rows {
        [count] -> {
          io.println("Count retrieved successfully: " <> int.to_string(count))
          Ok(count)
        }
        _ -> {
          io.println("Unexpected result format")
          Error("Unexpected result format")
        }
      }
    }
    Error(err) -> {
      let error_message = query_error_to_string(err)
      io.println("Failed to get count: " <> error_message)
      Error("Failed to get count: " <> error_message)
    }
  }
}

fn query_error_to_string(error: pgo.QueryError) -> String {
  case error {
    pgo.ConstraintViolated(message: message, constraint: constraint, detail: detail) ->
      "Constraint violated: " <> message <> " (Constraint: " <> constraint <> ", Detail: " <> detail <> ")"
    pgo.PostgresqlError(code: code, name: name, message: message) ->
      "PostgreSQL error: " <> message <> " (Code: " <> code <> ", Name: " <> name <> ")"
    pgo.UnexpectedArgumentCount(expected: expected, got: got) ->
      "Unexpected argument count. Expected: " <> int.to_string(expected) <> ", Got: " <> int.to_string(got)
    pgo.UnexpectedArgumentType(expected: expected, got: got) ->
      "Unexpected argument type. Expected: " <> expected <> ", Got: " <> got
    pgo.UnexpectedResultType(errors) ->
      "Unexpected result type: " <> string.inspect(errors)
    pgo.ConnectionUnavailable ->
      "Connection unavailable"
  }
}