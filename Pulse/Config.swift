import Foundation

enum Config {
    /// Supabase project — auth only. Data goes through the Flask API.
    static let supabaseURL = URL(string: "https://dgoggkkqkiuoxghsicgt.supabase.co")!

    /// Supabase ANON (public) key — never the service_role key.
    static let supabaseAnonKey = "sb_publishable_OuTJ09Y4Irqfuqza-W4puQ_SlWZx8Fk"

    #if DEBUG
    /// Local dev: flask runs on :3000.
    /// 127.0.0.1 (not localhost) — the dev server is IPv4-only and ::1 fails.
    static let apiBaseURL = URL(string: "http://127.0.0.1:3000")!
    #else
    static let apiBaseURL = URL(string: "https://pulse-api-production-15ed.up.railway.app")!
    #endif
}
