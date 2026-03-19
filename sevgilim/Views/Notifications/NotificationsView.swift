//
//  NotificationsView.swift
//  sevgilim
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var notificationHistoryService: NotificationHistoryService
    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    
    private var unreadCount: Int {
        authService.currentUser?.unreadNotificationCount ?? notificationHistoryService.unreadCount
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 48, height: 5)
                .padding(.top, 8)
            
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bildirimler")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount) okunmamış bildirim")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if unreadCount > 0 {
                    Button("Okundu Yap") {
                        Task {
                            await notificationHistoryService.markAllAsRead()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            if notificationHistoryService.notifications.isEmpty {
                ScrollView {
                    EmptyNotificationState(
                        systemImage: "bell.slash",
                        title: "Şimdilik Bildirim Yok",
                        message: "Gerçek push geçmişin burada görünecek."
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            } else {
                List {
                    ForEach(notificationHistoryService.notifications) { notification in
                        NotificationRow(item: notification) {
                            await handleNotificationTap(notification)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !notification.isRead {
                                Button {
                                    Task {
                                        await notificationHistoryService.markAsRead(notification)
                                    }
                                } label: {
                                    Label("Okundu yap", systemImage: "checkmark")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await notificationHistoryService.deleteNotification(notification)
                                }
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) async {
        await notificationHistoryService.markAsRead(notification)
        
        guard AppNavigationRouter.target(forNotificationType: notification.type) != nil else {
            return
        }
        
        dismiss()
        navigationRouter.open(notificationType: notification.type)
    }
}

// MARK: - Row

private struct NotificationRow: View {
    let item: AppNotification
    let onTap: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await onTap()
            }
        } label: {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                    
                    Image(systemName: item.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .foregroundColor(.accentColor)
                }
                .frame(width: 46, height: 46)
                .overlay(alignment: .topTrailing) {
                    if !item.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                            .offset(x: 4, y: -2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline.weight(item.isRead ? .semibold : .bold))
                        .multilineTextAlignment(.leading)
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundColor(item.isRead ? .secondary : .primary.opacity(0.78))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text(item.createdAt.timeAgo())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let deliveryStateLabel = item.deliveryStateLabel {
                            Text(deliveryStateLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.12))
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if let thumbnailURL = item.thumbnailURL {
                    CachedAsyncImage(url: thumbnailURL, thumbnail: true) { image, _ in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.2))
                            .overlay {
                                ProgressView()
                            }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        item.isRead ?
                        Color(.secondarySystemBackground) :
                        Color.blue.opacity(0.08)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                item.isRead ?
                                Color.clear :
                                Color.blue.opacity(0.22),
                                lineWidth: item.isRead ? 0 : 1
                            )
                    }
            )
            .opacity(item.isRead ? 0.92 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

private struct EmptyNotificationState: View {
    let systemImage: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}
