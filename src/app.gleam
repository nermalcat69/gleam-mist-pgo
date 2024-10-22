import gleam/list
import mist
import gleam/erlang/process
import gleam/bytes_builder
import gleam/http/response.{Response}
import gleam/string
import gleam/io
import gleam/int
import gleam/erlang/os
import gleam/result
import glenvy/dotenv
import glenvy/env
import database
import config

pub fn main() {
  // Load and verify environment variables at startup
  case dotenv.load() {
    Ok(_) -> {
      io.println("Environment variables loaded")
      case env.get_string("DATABASE_URL") {
        Ok(_) -> io.println("DATABASE_URL is set")
        Error(_) -> io.println("DATABASE_URL is not set")
      }
    }
    Error(_) -> {
      io.println("Failed to load environment variables: ")
    }
  }

  let port =
    os.get_env("PORT")
    |> result.then(int.parse)
    |> result.unwrap(3000)

  let assert Ok(_) =
    web_service
    |> mist.new
    |> mist.port(port)
    |> mist.start_http

  ["Started listening on localhost:", int.to_string(port), " ✨"]
  |> string.concat
  |> io.println

  process.sleep_forever()
}

fn web_service(_request) {
  io.println("Received a new request")
  // Check database connection using config
  let #(db_status, entry_count, latest_uuid, entries) = case config.get_db_connection() {
    Ok(connection) -> {
      io.println("Database connection successful")
      // Use the database module to add entry and get count
      case database.add_entry_and_get_count(connection) {
        Ok(#(uuid, count)) -> {
          io.println("Successfully added entry with UUID: " <> uuid)
          io.println("Total count: " <> int.to_string(count))
          
          case database.get_all_entries(connection) {
            Ok(entries) -> #("Database connection successful! ✅", count, uuid, entries)
            Error(_) -> #("Database connection successful! ✅", count, uuid, [])
          }
        }
        Error(err) -> {
          io.println("Database operation failed: " <> err)
          #("Database operation failed: " <> err, 0, "", [])
        }
      }
    }
    Error(err) -> {
      let error_message = case err {
        Nil -> "Unknown database connection error"
      }
      io.println(error_message)
      #(error_message <> " ❌", 0, "", [])
    }
  }

  io.println("Preparing response")
  let body = bytes_builder.from_string(
    "<!DOCTYPE html>
    <html>
    <head>
      <meta charset=\"UTF-8\">
      <title>Gleam Mist Application on Zerops</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          max-width: 800px;
          margin: 20px auto;
          padding: 0 20px;
        }
        .status {
          padding: 10px;
          margin: 10px 0;
          border-radius: 4px;
        }
        .success {
          background-color: #e6ffe6;
          border: 1px solid #00cc00;
        }
        .error {
          background-color: #ffe6e6;
          border: 1px solid #cc0000;
        }
        .count {
          font-size: 24px;
          font-weight: bold;
          margin: 20px 0;
        }
        .uuid {
          font-family: monospace;
          background-color: #f5f5f5;
          padding: 5px 10px;
          border-radius: 4px;
          margin: 10px 0;
        }
        .latest-entry {
          border: 2px solid #4CAF50;
          padding: 10px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .entries-table {
          width: 100%;
          border-collapse: collapse;
          margin: 20px 0;
          background-color: #fff;
          box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .entries-table th,
        .entries-table td {
          padding: 12px;
          text-align: left;
          border-bottom: 1px solid #ddd;
        }
        .entries-table th {
          background-color: #f8f9fa;
          font-weight: bold;
        }
        .entries-table tr:hover {
          background-color: #f5f5f5;
        }
        .new-entry {
          background-color: #e8f5e9;
          animation: highlight 2s ease-out;
        }
        @keyframes highlight {
          0% { background-color: #b9f6ca; }
          100% { background-color: #e8f5e9; }
        }
      </style>
    </head>
    <body>
      <h1>Gleam Mist Application</h1>
      <div class=\"status " <> case string.contains(db_status, "successful") {
        True -> "success"
        False -> "error"
      } <> "\">
        " <> db_status <> "
      </div>

      <div class=\"count\">
        Total entries: " <> int.to_string(entry_count) <> "
      </div>

      " <> case string.length(latest_uuid) > 0 {
        True -> "
          <div class=\"latest-entry\">
            <h3>Latest Entry</h3>
            <div class=\"uuid\">" <> latest_uuid <> "</div>
                  " <> case entries {
        [] -> ""
        entries -> "
          <h3>Recent Entries</h3>
          <table class=\"entries-table\">
            <thead>
              <tr>
                <th>UUID</th>
                <th>Created At</th>
              </tr>
            </thead>
            <tbody>
              " <> string.join(
                list.map(entries, fn(entry) {
                  let #(uuid, timestamp) = entry
                  "<tr class=\"" <> case uuid == latest_uuid {
                    True -> "new-entry"
                    False -> ""
                  } <> "\">
                    <td class=\"uuid\">" <> uuid <> "</td>
                    <td>" <> timestamp <> "</td>
                  </tr>"
                }),
                ""
              ) <> "
            </tbody>
          </table>"
      } <> "
          </div>"
        False -> ""
      } <> "

      <p>This is a simple, basic Gleam mist application running on Zerops.io, each request adds an entry with a UUID to the PostgreSQL database and returns a count.</p>
      <p>See the <a href='https://github.com/zeropsio/recipe-gleam' target='_blank'> source repository </a> for more information.</p>
    </body>
    </html>"
  )

  io.println("Sending response")
  Response(200, [#("Content-Type", "text/html")], mist.Bytes(body))
}