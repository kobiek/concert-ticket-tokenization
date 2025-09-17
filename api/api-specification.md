# API Specification: Concert Ticket Tokenization Platform

## Overview

This document defines the comprehensive API specification for the concert ticket tokenization platform, including RESTful endpoints, WebSocket connections, and integration specifications.

## Base Configuration

- **Base URL**: `https://api.concerttickets.io/v1`
- **Authentication**: JWT + Web3 wallet signatures
- **Rate Limiting**: 1000 requests per hour per API key
- **Content Type**: `application/json`
- **API Version**: v1

## Authentication

### 1. JWT Authentication

```javascript
// Request headers
{
  "Authorization": "Bearer <jwt_token>",
  "Content-Type": "application/json",
  "X-API-Key": "<api_key>"
}
```

### 2. Web3 Wallet Authentication

```javascript
// Wallet signature verification
{
  "X-Wallet-Address": "0x...",
  "X-Wallet-Signature": "0x...",
  "X-Wallet-Message": "Sign this message to authenticate"
}
```

## Core API Endpoints

### 1. Event Management

#### Get Events
```http
GET /events
```

**Query Parameters:**
- `page` (integer): Page number (default: 1)
- `limit` (integer): Items per page (default: 20)
- `category` (string): Event category filter
- `venue` (string): Venue filter
- `date_from` (string): Start date filter (ISO 8601)
- `date_to` (string): End date filter (ISO 8601)
- `status` (string): Event status (upcoming, live, ended)

**Response:**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "id": "evt_123456",
        "name": "Taylor Swift Eras Tour",
        "venue": "Madison Square Garden",
        "date": "2024-06-15T20:00:00Z",
        "location": "New York, NY",
        "category": "concert",
        "status": "upcoming",
        "ticketCount": 15000,
        "availableTickets": 5000,
        "priceRange": {
          "min": 150.00,
          "max": 500.00
        },
        "imageUrl": "https://...",
        "description": "The Eras Tour is coming to MSG...",
        "createdAt": "2024-01-15T10:00:00Z",
        "updatedAt": "2024-01-15T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "pages": 8
    }
  }
}
```

#### Get Event Details
```http
GET /events/{eventId}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "evt_123456",
    "name": "Taylor Swift Eras Tour",
    "venue": "Madison Square Garden",
    "date": "2024-06-15T20:00:00Z",
    "location": "New York, NY",
    "category": "concert",
    "status": "upcoming",
    "capacity": 20000,
    "soldTickets": 15000,
    "availableTickets": 5000,
    "priceTiers": [
      {
        "name": "VIP",
        "price": 500.00,
        "currency": "USD",
        "available": 100,
        "benefits": ["Meet & Greet", "Exclusive Merchandise"]
      },
      {
        "name": "General Admission",
        "price": 150.00,
        "currency": "USD",
        "available": 4900,
        "benefits": ["General Access"]
      }
    ],
    "artists": ["Taylor Swift"],
    "imageUrl": "https://...",
    "description": "The Eras Tour is coming to MSG...",
    "termsAndConditions": "https://...",
    "createdAt": "2024-01-15T10:00:00Z",
    "updatedAt": "2024-01-15T10:00:00Z"
  }
}
```

### 2. Ticket Management

#### Get Available Tickets
```http
GET /events/{eventId}/tickets
```

**Query Parameters:**
- `price_min` (number): Minimum price filter
- `price_max` (number): Maximum price filter
- `section` (string): Venue section filter
- `row` (string): Row filter
- `seat_type` (string): Seat type filter
- `sort` (string): Sort by (price, section, row)
- `order` (string): Sort order (asc, desc)

**Response:**
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": "tkt_789012",
        "eventId": "evt_123456",
        "section": "Floor A",
        "row": "5",
        "seat": "12",
        "price": 250.00,
        "currency": "USD",
        "seatType": "VIP",
        "isFractional": false,
        "totalFractions": 1,
        "availableFractions": 1,
        "owner": null,
        "status": "available",
        "metadata": {
          "view": "Stage View",
          "accessibility": "Wheelchair Accessible",
          "amenities": ["VIP Lounge Access"]
        },
        "createdAt": "2024-01-15T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 5000,
      "pages": 250
    }
  }
}
```

#### Purchase Ticket
```http
POST /tickets/purchase
```

**Request Body:**
```json
{
  "ticketId": "tkt_789012",
  "paymentMethod": "stripe",
  "paymentDetails": {
    "cardToken": "tok_visa",
    "billingAddress": {
      "line1": "123 Main St",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "US"
    }
  },
  "userInfo": {
    "email": "user@example.com",
    "name": "John Doe",
    "phone": "+1234567890"
  },
  "walletAddress": "0x742d35Cc6634C0532925a3b8D0C4e3C4C4C4C4C4C"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "transactionId": "txn_abc123",
    "paymentId": "pi_1234567890",
    "nftTokenId": "12345",
    "nftContractAddress": "0x...",
    "status": "processing",
    "estimatedCompletion": "2024-01-15T10:05:00Z",
    "receipt": {
      "ticketId": "tkt_789012",
      "eventName": "Taylor Swift Eras Tour",
      "venue": "Madison Square Garden",
      "date": "2024-06-15T20:00:00Z",
      "section": "Floor A",
      "row": "5",
      "seat": "12",
      "price": 250.00,
      "currency": "USD",
      "fees": {
        "platform": 12.50,
        "processing": 7.25,
        "total": 19.75
      },
      "total": 269.75
    }
  }
}
```

#### Get User Tickets
```http
GET /users/{userId}/tickets
```

**Query Parameters:**
- `status` (string): Ticket status filter (active, used, transferred)
- `event_id` (string): Filter by event ID
- `page` (integer): Page number
- `limit` (integer): Items per page

**Response:**
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": "tkt_789012",
        "nftTokenId": "12345",
        "eventId": "evt_123456",
        "eventName": "Taylor Swift Eras Tour",
        "venue": "Madison Square Garden",
        "date": "2024-06-15T20:00:00Z",
        "section": "Floor A",
        "row": "5",
        "seat": "12",
        "price": 250.00,
        "currency": "USD",
        "status": "active",
        "isFractional": false,
        "fractionalOwnership": 1.0,
        "transferable": true,
        "used": false,
        "metadata": {
          "imageUrl": "https://...",
          "qrCode": "https://...",
          "barcode": "1234567890"
        },
        "purchasedAt": "2024-01-15T10:00:00Z",
        "expiresAt": "2024-06-15T23:59:59Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 5,
      "pages": 1
    }
  }
}
```

### 3. Marketplace API

#### List Ticket for Sale
```http
POST /marketplace/list
```

**Request Body:**
```json
{
  "ticketId": "tkt_789012",
  "price": 300.00,
  "currency": "USD",
  "isAuction": false,
  "auctionDuration": null,
  "minimumBid": null,
  "reservePrice": null,
  "expiresAt": "2024-06-10T20:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "listingId": "lst_456789",
    "ticketId": "tkt_789012",
    "nftTokenId": "12345",
    "price": 300.00,
    "currency": "USD",
    "isAuction": false,
    "status": "active",
    "createdAt": "2024-01-15T10:00:00Z",
    "expiresAt": "2024-06-10T20:00:00Z"
  }
}
```

#### Get Marketplace Listings
```http
GET /marketplace/listings
```

**Query Parameters:**
- `event_id` (string): Filter by event ID
- `price_min` (number): Minimum price filter
- `price_max` (number): Maximum price filter
- `is_auction` (boolean): Filter by auction status
- `status` (string): Listing status filter
- `sort` (string): Sort by (price, created_at, ending_soon)
- `order` (string): Sort order (asc, desc)

**Response:**
```json
{
  "success": true,
  "data": {
    "listings": [
      {
        "id": "lst_456789",
        "ticketId": "tkt_789012",
        "nftTokenId": "12345",
        "eventName": "Taylor Swift Eras Tour",
        "venue": "Madison Square Garden",
        "date": "2024-06-15T20:00:00Z",
        "section": "Floor A",
        "row": "5",
        "seat": "12",
        "price": 300.00,
        "currency": "USD",
        "isAuction": false,
        "status": "active",
        "seller": {
          "id": "usr_123",
          "username": "ticketmaster",
          "rating": 4.8,
          "verified": true
        },
        "timeRemaining": "5d 12h 30m",
        "createdAt": "2024-01-15T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "pages": 8
    }
  }
}
```

#### Buy Ticket from Marketplace
```http
POST /marketplace/buy
```

**Request Body:**
```json
{
  "listingId": "lst_456789",
  "paymentMethod": "stripe",
  "paymentDetails": {
    "cardToken": "tok_visa"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "transactionId": "txn_def456",
    "paymentId": "pi_0987654321",
    "nftTokenId": "12345",
    "status": "processing",
    "estimatedCompletion": "2024-01-15T10:05:00Z"
  }
}
```

### 4. Payment API

#### Create Payment Intent
```http
POST /payments/create
```

**Request Body:**
```json
{
  "amount": 250.00,
  "currency": "USD",
  "paymentMethod": "stripe",
  "ticketId": "tkt_789012",
  "userAddress": "0x742d35Cc6634C0532925a3b8D0C4e3C4C4C4C4C4C"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "paymentId": "pi_1234567890",
    "clientSecret": "pi_1234567890_secret_...",
    "amount": 250.00,
    "currency": "USD",
    "status": "requires_payment_method",
    "paymentUrl": "https://checkout.stripe.com/...",
    "expiresAt": "2024-01-15T10:15:00Z"
  }
}
```

#### Verify Payment
```http
POST /payments/verify
```

**Request Body:**
```json
{
  "paymentId": "pi_1234567890",
  "transactionHash": "0x..."
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "verified": true,
    "nftTokenId": "12345",
    "transactionHash": "0x...",
    "blockNumber": 12345678,
    "gasUsed": 150000,
    "status": "confirmed"
  }
}
```

### 5. User Management

#### Get User Profile
```http
GET /users/{userId}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "usr_123",
    "username": "ticketmaster",
    "email": "user@example.com",
    "walletAddress": "0x742d35Cc6634C0532925a3b8D0C4e3C4C4C4C4C4C",
    "profile": {
      "firstName": "John",
      "lastName": "Doe",
      "avatar": "https://...",
      "bio": "Concert enthusiast",
      "location": "New York, NY"
    },
    "stats": {
      "ticketsPurchased": 15,
      "ticketsSold": 3,
      "totalSpent": 2500.00,
      "totalEarned": 750.00,
      "rating": 4.8,
      "verified": true
    },
    "preferences": {
      "notifications": {
        "email": true,
        "push": true,
        "sms": false
      },
      "privacy": {
        "publicProfile": true,
        "showWallet": false
      }
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-15T10:00:00Z"
  }
}
```

#### Update User Profile
```http
PUT /users/{userId}
```

**Request Body:**
```json
{
  "profile": {
    "firstName": "John",
    "lastName": "Doe",
    "bio": "Concert enthusiast and NFT collector",
    "location": "New York, NY"
  },
  "preferences": {
    "notifications": {
      "email": true,
      "push": false,
      "sms": false
    }
  }
}
```

### 6. Verification API

#### Verify Ticket Entry
```http
POST /verification/verify-entry
```

**Request Body:**
```json
{
  "ticketId": "tkt_789012",
  "nftTokenId": "12345",
  "verificationCode": "QR_CODE_DATA",
  "verifierId": "ver_123",
  "location": {
    "venue": "Madison Square Garden",
    "gate": "Gate A",
    "coordinates": {
      "lat": 40.7505,
      "lng": -73.9934
    }
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "verified": true,
    "ticketId": "tkt_789012",
    "nftTokenId": "12345",
    "eventName": "Taylor Swift Eras Tour",
    "venue": "Madison Square Garden",
    "section": "Floor A",
    "row": "5",
    "seat": "12",
    "verificationTime": "2024-06-15T19:45:00Z",
    "verifierId": "ver_123",
    "location": "Gate A"
  }
}
```

## WebSocket API

### Connection
```javascript
const ws = new WebSocket('wss://api.concerttickets.io/v1/ws');
```

### Authentication
```javascript
ws.send(JSON.stringify({
  type: 'auth',
  token: 'jwt_token',
  walletAddress: '0x...'
}));
```

### Event Subscriptions

#### Ticket Price Updates
```javascript
ws.send(JSON.stringify({
  type: 'subscribe',
  channel: 'ticket_prices',
  ticketId: 'tkt_789012'
}));
```

#### Marketplace Activity
```javascript
ws.send(JSON.stringify({
  type: 'subscribe',
  channel: 'marketplace',
  eventId: 'evt_123456'
}));
```

### Real-time Events

#### Price Update
```json
{
  "type": "price_update",
  "data": {
    "ticketId": "tkt_789012",
    "oldPrice": 250.00,
    "newPrice": 275.00,
    "currency": "USD",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### New Listing
```json
{
  "type": "new_listing",
  "data": {
    "listingId": "lst_456789",
    "ticketId": "tkt_789012",
    "eventName": "Taylor Swift Eras Tour",
    "price": 300.00,
    "currency": "USD",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

## Error Handling

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "The request is invalid",
    "details": {
      "field": "ticketId",
      "reason": "Ticket not found"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "req_123456"
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_REQUEST` | 400 | Invalid request parameters |
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource conflict |
| `RATE_LIMITED` | 429 | Rate limit exceeded |
| `PAYMENT_FAILED` | 402 | Payment processing failed |
| `TICKET_UNAVAILABLE` | 410 | Ticket no longer available |
| `INSUFFICIENT_FUNDS` | 402 | Insufficient funds |
| `BLOCKCHAIN_ERROR` | 500 | Blockchain transaction failed |
| `INTERNAL_ERROR` | 500 | Internal server error |

## Rate Limiting

### Limits by Endpoint Type

| Endpoint Type | Rate Limit | Window |
|---------------|------------|--------|
| Authentication | 10 requests | 1 minute |
| Ticket Purchase | 5 requests | 1 minute |
| Marketplace | 100 requests | 1 hour |
| General API | 1000 requests | 1 hour |
| WebSocket | 10 connections | per user |

### Rate Limit Headers
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642248000
```

## SDK Examples

### JavaScript/Node.js
```javascript
import ConcertTicketsAPI from '@concerttickets/api-client';

const api = new ConcertTicketsAPI({
  apiKey: 'your_api_key',
  baseUrl: 'https://api.concerttickets.io/v1'
});

// Get events
const events = await api.events.list({
  category: 'concert',
  date_from: '2024-06-01',
  date_to: '2024-06-30'
});

// Purchase ticket
const purchase = await api.tickets.purchase({
  ticketId: 'tkt_789012',
  paymentMethod: 'stripe',
  paymentDetails: {
    cardToken: 'tok_visa'
  }
});
```

### Python
```python
from concerttickets import ConcertTicketsAPI

api = ConcertTicketsAPI(
    api_key='your_api_key',
    base_url='https://api.concerttickets.io/v1'
)

# Get events
events = api.events.list(
    category='concert',
    date_from='2024-06-01',
    date_to='2024-06-30'
)

# Purchase ticket
purchase = api.tickets.purchase(
    ticket_id='tkt_789012',
    payment_method='stripe',
    payment_details={
        'card_token': 'tok_visa'
    }
)
```

This comprehensive API specification provides the foundation for building a robust concert ticket tokenization platform with full marketplace functionality, payment processing, and real-time updates.
