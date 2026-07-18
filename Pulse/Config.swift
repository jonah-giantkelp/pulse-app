import Foundation

enum Config {
    /// Supabase project — auth only. Data goes through the Flask API.
    static let supabaseURL = URL(string: "https://dgoggkkqkiuoxghsicgt.supabase.co")!

    /// TODO: paste the Supabase ANON (public) key — never the service_role key.
    static let supabaseAnonKey = "sb_publishable_OuTJ09Y4Irqfuqza-W4puQ_SlWZx8Fk"

    /// TODO: point at the deployed Flask API. Local dev: flask runs on :3000.
    /// 127.0.0.1 (not localhost) — the dev server is IPv4-only and ::1 fails.
    static let apiBaseURL = URL(string: "http://127.0.0.1:3000")!
}
