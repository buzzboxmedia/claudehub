import Foundation
import os.log

class ClaudeAPI {
    static let shared = ClaudeAPI()
    private let logger = Logger(subsystem: "com.buzzbox.claudehub", category: "ClaudeAPI")

    private var apiKey: String? {
        // Try environment variable first
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            logger.info("Using API key from environment variable")
            return key
        }
        // Then try UserDefaults
        if let key = UserDefaults.standard.string(forKey: "anthropic_api_key"), !key.isEmpty {
            logger.info("Using API key from UserDefaults")
            return key
        }
        logger.warning("No API key found in environment or UserDefaults")
        return nil
    }

    func summarizeChat(content: String, completion: @escaping (String?) -> Void) {
        logger.info("summarizeChat called with \(content.count) characters")

        guard let apiKey = apiKey else {
            logger.error("No Anthropic API key found - cannot summarize")
            completion(nil)
            return
        }

        guard !content.isEmpty else {
            logger.warning("Empty content provided - skipping summarization")
            completion(nil)
            return
        }

        // Truncate content if too long
        let truncatedContent = String(content.prefix(4000))
        logger.info("Truncated content to \(truncatedContent.count) characters")

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let prompt = """
        Based on this terminal session with Claude, generate a very short title (3-6 words) that describes what the conversation is about. Just respond with the title, nothing else.

        Terminal content:
        \(truncatedContent)
        """

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 50,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            logger.info("Request body serialized successfully")
        } catch {
            logger.error("Failed to serialize request: \(error.localizedDescription)")
            completion(nil)
            return
        }

        logger.info("Sending API request to Anthropic...")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.logger.error("API request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                self?.logger.info("API response status: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                self?.logger.error("No data received from API")
                completion(nil)
                return
            }

            self?.logger.info("Received \(data.count) bytes from API")

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.logger.info("Successfully extracted title: '\(title)'")
                    DispatchQueue.main.async {
                        completion(title)
                    }
                } else {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        self?.logger.error("Unexpected API response format: \(jsonString.prefix(500))")
                    }
                    completion(nil)
                }
            } catch {
                self?.logger.error("Failed to parse API response: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }

    /// Generate a short title from user's first input
    func generateTitle(from userInput: String, completion: @escaping (String?) -> Void) {
        logger.info("generateTitle called with: '\(userInput.prefix(100))'")

        guard let apiKey = apiKey else {
            logger.error("No Anthropic API key found - cannot generate title")
            completion(nil)
            return
        }

        guard !userInput.isEmpty else {
            logger.warning("Empty input provided - skipping title generation")
            completion(nil)
            return
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let prompt = """
        Generate a very short title (3-6 words) for this task or question. Just respond with the title, nothing else. Make it descriptive and action-oriented.

        User's input:
        \(userInput.prefix(500))
        """

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 30,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize request: \(error.localizedDescription)")
            completion(nil)
            return
        }

        logger.info("Sending title generation request...")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.logger.error("API request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                self?.logger.error("No data received from API")
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.logger.info("Generated title: '\(title)'")
                    DispatchQueue.main.async {
                        completion(title)
                    }
                } else {
                    self?.logger.error("Unexpected API response format")
                    completion(nil)
                }
            } catch {
                self?.logger.error("Failed to parse API response: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }

    /// Generate a billable summary and estimated hours from terminal content
    func generateBillableSummary(from content: String, taskName: String, completion: @escaping (BillableSummary?) -> Void) {
        logger.info("generateBillableSummary called for task: '\(taskName)'")

        guard let apiKey = apiKey else {
            logger.error("No Anthropic API key found - cannot generate summary")
            completion(nil)
            return
        }

        guard !content.isEmpty else {
            logger.warning("Empty content provided - skipping summary generation")
            completion(nil)
            return
        }

        let truncatedContent = String(content.suffix(6000))

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let prompt = """
        Based on this terminal session, generate a billable time entry for invoicing.

        Task name: \(taskName)

        Terminal content:
        \(truncatedContent)

        Respond in JSON format only, no other text:
        {
            "description": "Short action phrase for invoice, e.g. 'Designed social media graphics' or 'Fixed checkout page bug' (max 10 words)",
            "estimated_hours": 0.5,
            "reasoning": "Brief explanation of hour estimate"
        }

        Base the estimated hours on typical agency rates for this type of work. Common ranges:
        - Quick fix/review: 0.25-0.5 hrs
        - Small task: 0.5-1 hr
        - Medium task: 1-2 hrs
        - Complex task: 2-4 hrs
        """

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize request: \(error.localizedDescription)")
            completion(nil)
            return
        }

        logger.info("Sending billable summary request...")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.logger.error("API request failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data else {
                self?.logger.error("No data received from API")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {

                    // Parse the JSON response from Claude
                    if let jsonData = text.data(using: .utf8),
                       let summaryJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let description = summaryJson["description"] as? String {

                        let estimatedHours = summaryJson["estimated_hours"] as? Double ?? 0.5

                        let summary = BillableSummary(
                            description: description,
                            estimatedHours: estimatedHours
                        )

                        self?.logger.info("Generated billable summary: '\(description)' (\(estimatedHours) hrs)")
                        DispatchQueue.main.async { completion(summary) }
                    } else {
                        self?.logger.error("Could not parse Claude's JSON response: \(text)")
                        DispatchQueue.main.async { completion(nil) }
                    }
                } else {
                    self?.logger.error("Unexpected API response format")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                self?.logger.error("Failed to parse API response: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    /// Generate a brief summary of what was accomplished in a task (for completion)
    func generateTaskSummary(from content: String, taskName: String, completion: @escaping (String?) -> Void) {
        logger.info("generateTaskSummary called for task: '\(taskName)'")

        guard let apiKey = apiKey else {
            logger.warning("No API key - using task name as summary")
            completion(taskName)
            return
        }

        guard !content.isEmpty else {
            logger.warning("Empty content - using task name as summary")
            completion(taskName)
            return
        }

        let truncatedContent = String(content.suffix(4000))

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let prompt = """
        Based on this terminal session, write a brief 1-2 sentence summary of what was accomplished.
        Focus on the outcome and any key decisions made. Keep it concise for display in a sidebar.

        Task name: \(taskName)

        Terminal content:
        \(truncatedContent)

        Respond with just the summary text, no quotes or formatting.
        Example: "Implemented the login form with email validation. Added error handling for failed attempts."
        """

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 150,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize request: \(error.localizedDescription)")
            completion(taskName)
            return
        }

        logger.info("Sending task summary request...")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.logger.error("API request failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(taskName) }
                return
            }

            guard let data = data else {
                self?.logger.error("No data received from API")
                DispatchQueue.main.async { completion(taskName) }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {

                    let summary = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.logger.info("Generated task summary: '\(summary)'")
                    DispatchQueue.main.async { completion(summary) }
                } else {
                    self?.logger.error("Unexpected API response format")
                    DispatchQueue.main.async { completion(taskName) }
                }
            } catch {
                self?.logger.error("Failed to parse API response: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(taskName) }
            }
        }.resume()
    }

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "anthropic_api_key")
    }

    var hasAPIKey: Bool {
        apiKey != nil
    }
}

struct BillableSummary {
    let description: String
    let estimatedHours: Double
}
