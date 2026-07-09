import Foundation

protocol JiraDataService: Sendable {
    func projects(for resource: JiraAccessibleResource) async throws -> [Project]
    func issues(for project: Project) async throws -> [Issue]
}
