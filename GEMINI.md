# TODO: Implement Block & Unblock Features

## Overview
Implement comprehensive block and unblock features including reasons, restrictions, unblock requests, notifications, and relationship-based limits.

## Key Features to Implement
- Block User with Reason: User1 blocks User2 with a mandatory reason, stored in Firestore.
- Blocked User Restrictions: User2 cannot send messages; sees block reason instead of typing box.
- Unblock Request: User2 can send unblock request to User1 with optional message.
- Notification: User1 gets notified of unblock requests.
- Unblock Decision: User1 can accept or reject requests.
- Limits: Based on relationship (No relationship: 1, Friend: 2, Best Friend: 4, Family: unlimited).
- Single-use Requests: Each request counts against quota.

## Required Files to Change
- `lib/models/user_model.dart`: Add `blockReasons` map (blockedUserId: reason)
- `lib/models/unblock_request_model.dart`: New model for unblock requests
- `lib/services/relationship_service.dart`: Update blockUser to include reason, add unblock request functions, check limits
- `lib/providers/chat_provider.dart`: Update for block reasons
- `lib/providers/unblock_request_provider.dart`: New provider for unblock requests
- `lib/screens/home/chat_screen.dart`: Check if blocked, show block reason instead of input, add unblock request UI
- `lib/screens/profile/profile_screen.dart`: Update block to ask for reason, add unblock request management
- `lib/services/notification_service.dart`: Add notifications for unblock requests
- `lib/widgets/chat_input.dart`: Modify to show block reason if current user is blocked
- `lib/widgets/block_reason_display.dart`: New widget for displaying block reason and unblock request button
- `firestore.rules`: Add rules for `unblockRequests` collection
- `functions/index.js`: Add cloud function for unblock request notifications (optional)

## Implementation Steps
- [ ] Update `user_model.dart` to include `blockReasons` map
- [ ] Create `unblock_request_model.dart` with fields: id, fromUserId, toUserId, message, status, createdAt
- [ ] Update `relationship_service.dart`:
  - Modify `blockUser` to take reason parameter and store in `blockReasons`
  - Add `getBlockReason` function
  - Add `sendUnblockRequest` function
  - Add `getUnblockRequests` function
  - Add `acceptUnblockRequest` and `rejectUnblockRequest` functions
  - Add `checkUnblockRequestLimit` function based on relationship
- [ ] Create `unblock_request_provider.dart` for managing unblock requests state
- [ ] Update `chat_provider.dart` to handle block reasons
- [ ] Modify `chat_input.dart` to accept `isBlocked` and `blockReason` parameters, show block display if blocked
- [ ] Create `block_reason_display.dart` widget with reason text and "Send Unblock Request" button
- [ ] Update `chat_screen.dart`:
  - Check if current user is blocked by receiver using `isUserBlocked` (but reverse: check if receiver has current user in blockedUsers)
  - If blocked, replace `ChatInput` with `BlockReasonDisplay`
  - Implement unblock request dialog with optional message
- [ ] Update `profile_screen.dart`:
  - Modify block action to show dialog for reason input
  - Add section to view and manage unblock requests (accept/reject)
- [ ] Update `notification_service.dart` to send notification when unblock request is sent
- [ ] Test blocking with reason input
- [ ] Test blocked user seeing reason instead of input
- [ ] Test sending unblock requests with limits
- [ ] Test notifications for unblock requests
- [ ] Test accepting/rejecting requests
- [ ] Run full app test for runtime errors
