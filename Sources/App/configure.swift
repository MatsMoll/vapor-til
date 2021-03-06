/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import FluentPostgreSQL
import Vapor
import HTMLKitVaporProvider
import Authentication
import SendGrid

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
  /// Register providers first
  try services.register(FluentPostgreSQLProvider())
  try services.register(AuthenticationProvider())
//  try services.register(SendGridProvider())

  /// Register routes to the router
  let router = EngineRouter.default()
  try routes(router)
  services.register(router, as: Router.self)

  /// Register middleware
  var middlewares = MiddlewareConfig() // Create _empty_ middleware config
  middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
  middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
  middlewares.use(SessionsMiddleware.self)
  services.register(middlewares)

  // Configure a database
  var databases = DatabasesConfig()
  let databaseConfig: PostgreSQLDatabaseConfig
  if let url = Environment.get("DATABASE_URL") {
    databaseConfig = PostgreSQLDatabaseConfig(url: url)!
  } else if let url = Environment.get("DB_POSTGRESQL") {
    databaseConfig = PostgreSQLDatabaseConfig(url: url)!
  } else {
    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let username = Environment.get("DATABASE_USER") ?? "vapor"
    let password = Environment.get("DATABASE_PASSWORD")
    let databaseName: String
    let databasePort: Int
    if (env == .testing) {
      databaseName = "vapor-test"
      if let testPort = Environment.get("DATABASE_PORT") {
        databasePort = Int(testPort) ?? 5433
      } else {
        databasePort = 5433
      }
    } else {
      databaseName = Environment.get("DATABASE_DB") ?? "vapor"
      databasePort = 5432
    }

    databaseConfig = PostgreSQLDatabaseConfig(
      hostname: hostname,
      port: databasePort,
      username: username,
      database: databaseName,
      password: password)
  }
  let database = PostgreSQLDatabase(config: databaseConfig)
  databases.add(database: database, as: .psql)
  services.register(databases)

  /// Configure migrations
  var migrations = MigrationConfig()
  migrations.add(model: User.self, database: .psql)
  migrations.add(model: Acronym.self, database: .psql)
  migrations.add(model: Category.self, database: .psql)
  migrations.add(model: AcronymCategoryPivot.self, database: .psql)
  migrations.add(model: Token.self, database: .psql)
  migrations.add(migration: AdminUser.self, database: .psql)
  migrations.add(model: ResetPasswordToken.self, database: .psql)
  services.register(migrations)

    let renderer = HTMLRenderer()

    try renderer.add(view: IndexTemplate())

    try renderer.add(view: Acronym.Templates.Details())
    try renderer.add(view: Acronym.Templates.Create())
    try renderer.add(view: Acronym.Templates.List())

    try renderer.add(view: Category.Templates.Details())
    try renderer.add(view: Category.Templates.ListAll())

    try renderer.add(view: User.Templates.Details())
    try renderer.add(view: User.Templates.ListAll())
    try renderer.add(view: User.Templates.Login())
    try renderer.add(view: User.Templates.Register())
    try renderer.add(view: User.Templates.ResetPassword())
    try renderer.add(view: User.Templates.ForgottenPassword())
    try renderer.add(view: User.Templates.ForgottenPasswordConfirmed())
    try renderer.add(view: User.Templates.AddProfilePicture())

    services.register(renderer)

  var commandConfig = CommandConfig.default()
  commandConfig.useFluentCommands()
  services.register(commandConfig)

  config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)

  guard let sendGridAPIKey = Environment.get("SENDGRID_API_KEY") else {
    fatalError("No Send Grid API Key specified")
  }
  let sendGridConfig = SendGridConfig(apiKey: sendGridAPIKey)
  services.register(sendGridConfig)
}
