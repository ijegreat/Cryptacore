# Cryptacore

## Secure and Private Data Vault on the ClarityChain Network

Cryptacore is a decentralized application built on the ClarityChain Network that provides a secure, private data storage solution with granular access control and comprehensive activity logging.

## Overview

Cryptacore allows users to:
- Store encrypted or unencrypted data on the blockchain
- Control access permissions to their data with fine-grained controls
- Monitor activity logs of data access and modifications
- Set customizable privacy preferences
- Manage data records securely

## Features

### Data Security
- Store and retrieve content with encryption support
- User-controlled encryption settings
- Content type validation and tracking

### Access Control
- Granular permission system with read, write, and admin access levels
- Time-bound access via expiration settings
- Permission delegation controls
- Revocable access rights

### Privacy Management
- Customizable privacy preferences
- Optional activity logging
- Default encryption settings

### Activity Monitoring
- Comprehensive activity logs for all operations
- Support for audit trails
- Historical access review capabilities

## Contract Functions

### User Preferences
- `setup-preferences`: Initialize user privacy settings
- `update-preferences`: Modify existing privacy settings
- `get-preferences`: Retrieve current privacy configuration

### Record Management
- `save-record`: Create or update a data record
- `retrieve-record`: Access a stored record (with permission check)
- `remove-record`: Delete a data record
- `request-record-deletion`: Request removal of a record

### Permission Management
- `grant-permission`: Assign access rights to other users
- `revoke-permission`: Remove previously granted permissions
- `check-access`: Verify a user's access level to a specific record

### Activity Tracking
- `get-activity-history`: Review activity logs for specific records

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Record not found |
| u102 | Invalid permission type |
| u103 | Duplicate record |
| u104 | Access expired |
| u105 | Invalid block height |
| u106 | Invalid input |
| u107 | Invalid record ID |
| u108 | Invalid content |
| u109 | Invalid content type |
| u110 | Invalid recipient |

## Access Levels

- `read`: Permission to view records
- `write`: Permission to view and modify records
- `admin`: Full access including permission management
- `none`: No access granted

## Operation Types

- `read`: Record retrieval operation
- `create`: New record creation
- `update`: Existing record modification
- `delete`: Record removal
- `grant`: Permission assignment
- `revoke`: Permission removal
- `delete-req`: Deletion request

## Usage Examples

### Setting up user preferences
```clarity
(contract-call? .cryptacore setup-preferences "none" true true)
```

### Creating a new record
```clarity
(contract-call? .cryptacore save-record "medical-data-001" "Patient history data..." "medical/record" true)
```

### Granting access to another user
```clarity
(contract-call? .cryptacore grant-permission "medical-data-001" 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "read" u100000 false)
```

### Retrieving a record
```clarity
(contract-call? .cryptacore retrieve-record 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "medical-data-001")
```

### Revoking access
```clarity
(contract-call? .cryptacore revoke-permission "medical-data-001" 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Security Considerations

- All sensitive data should be encrypted client-side before storage
- Access control is enforced at the contract level
- Time-bound permissions should be used for temporary access
- Activity logging should be enabled for security-critical data
- Regular access reviews are recommended using the history functions

## Development and Contributions

Cryptacore is designed to be extended and enhanced to meet additional security and privacy requirements. Developers interested in contributing should focus on:

- Additional encryption methods
- Enhanced audit capabilities
- Integration with other ClarityChain services
- Improved permission management workflows
