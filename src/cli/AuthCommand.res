// AIDEV-NOTE: GitHub authentication command implementations
// Supports GitHub CLI and environment variables only (no persistence)
// Commands: test (validate auth), help (show instructions)

type source = [#"gh-cli" | #"env-var"]

type authConfig = {
  token: string,
  source: source,
  host: string,
}

type authDetails = {
  username: string,
  name: option<string>,
  email: option<string>,
  scopes: array<string>,
}

type authResult =
  | Success({config: authConfig})
  | Failure({reason: string})

@module("../lib/auth.js") external getGitHubAuthRaw: string => promise<{..}> = "getGitHubAuth"

// Convert the JS object to a proper ReScript variant
let getGitHubAuth = async () => {
  let result = await getGitHubAuthRaw("origin")

  switch result["kind"] {
  | "success" =>
    Success({
      config: {
        token: result["config"]["token"],
        source: switch result["config"]["source"] {
        | "gh-cli" => #"gh-cli"
        | "env-var" => #"env-var"
        | _ => Exn.raiseError("Unexpected config source")
        },
	host: result["config"]["host"],
      },
    })
  | "failure" => Failure({reason: result["reason"]})
  | _ => Failure({reason: "unknown"})
  }
}
@module("../lib/auth.js")
external getAuthDetails: authConfig => promise<authDetails> = "getAuthDetails"

let authInstructions = `🔐 GitHub Authentication Required
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
To create and manage pull requests, jj-stack needs access to GitHub.

Please set up authentication using one of these methods:
1. Install GitHub CLI and run: gh auth login
2. Set environment variable: export GITHUB_TOKEN=your_token
   (Create a token at: https://github.com/settings/tokens/new)

Required token permissions:
• repo (Full control of private repositories)
• pull_requests (Create and update pull requests)`

// CLI wrapper that provides user-facing messaging
let getGitHubAuthCli = async () => {
  let result = await getGitHubAuth()

  switch result {
  | Success({config}) => {
      // Show success message based on source
      let sourceMessage = switch config.source {
      | #"gh-cli" => "✅ Using GitHub CLI authentication"
      | #"env-var" => "✅ Using GitHub token from environment variable"
      }
      Console.log(sourceMessage)

      // Return the config
      config
    }
  | Failure({reason}) => {
      // Show failure instructions and throw
      if reason == "invalid-token" {
        Console.warn("⚠️  GitHub token from environment variable is invalid")
      }
      Console.error("\n" ++ authInstructions)
      Exn.raiseError("GitHub authentication required. Please set up authentication and try again.")
    }
  }
}

let sourceToString = (source: source): string => {
  switch source {
  | #"gh-cli" => "GitHub CLI"
  | #"env-var" => "Environment Variable"
  }
}

let authTestCommand = async () => {
  Console.log("🔐 Testing GitHub Authentication...\n")

  let authConfig = await getGitHubAuthCli()

  // Test the authentication by making a simple API call
  let authDetails = await getAuthDetails(authConfig)

  let nameStr = switch authDetails.name {
  | Some(name) => name
  | None => "No name set"
  }
  Console.log(`👤 Authenticated as: ${authDetails.username} (${nameStr})`)

  let emailStr = switch authDetails.email {
  | Some(email) => email
  | None => "Not public"
  }
  Console.log(`📧 Email: ${emailStr}`)

  let scopesStr =
    authDetails.scopes->Array.length > 0 ? authDetails.scopes->Array.join(", ") : "None detected"
  Console.log(`📋 Token scopes: ${scopesStr}`)

  if authDetails.scopes->Array.includes("repo") {
    Console.log("✅ Token has repo access (required for creating PRs)")
  } else {
    Console.log("⚠️  Token may not have sufficient permissions for creating PRs")
  }
}

let authHelpCommand = () => {
  Console.log(`🔐 GitHub Authentication Help
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
jj-stack supports the following authentication methods (in priority order):

1. 🛠️  GitHub CLI (recommended)
   Install: https://cli.github.com/
   Setup: gh auth login

2. 🌍 Environment Variables
   export GITHUB_TOKEN=your_token_here
   export GH_TOKEN=your_token_here  # Alternative name
   
   Create a Personal Access Token at: https://github.com/settings/tokens/new
   Required scopes: repo, pull_requests

Commands:
  jj-stack auth test - Test current authentication
  jj-stack auth help - Show this help

Note: jj-stack no longer stores tokens locally for security reasons.
Use GitHub CLI or environment variables for authentication.
`)
}
