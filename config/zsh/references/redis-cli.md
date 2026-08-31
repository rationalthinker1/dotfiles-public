# 🧠 redis-cli Cheat Sheet

## 🔍 Connecting

```bash
redis-cli                                       # Connect to localhost:6379
redis-cli -h 192.168.1.10                       # Connect to remote host
redis-cli -h host -p 6380                       # Connect on non-default port
redis-cli -a password                            # Connect with password
redis-cli -n 2                                   # Connect to database 2 (default is 0)
redis-cli -u redis://user:pass@host:6379/0      # Connect via URI
redis-cli --tls                                  # Connect with TLS encryption
```

## 🔑 Key Operations

```bash
SET key "value"                                  # Set a key
GET key                                          # Get value of key
DEL key                                          # Delete key
DEL key1 key2 key3                               # Delete multiple keys
EXISTS key                                       # Check if key exists (returns 1 or 0)
TYPE key                                         # Get data type of key (string, list, set, hash, zset)
RENAME key newkey                                # Rename a key
KEYS "user:*"                                    # Find keys matching pattern (slow on large DBs)
SCAN 0 MATCH "user:*" COUNT 100                  # Iterate keys safely (cursor-based, production-safe)
RANDOMKEY                                        # Return a random key
```

## ⏱️ Expiration

```bash
EXPIRE key 3600                                  # Set TTL to 3600 seconds
PEXPIRE key 5000                                 # Set TTL in milliseconds
EXPIREAT key 1735689600                          # Expire at Unix timestamp
TTL key                                          # Check remaining TTL (seconds, -1 = no expiry, -2 = gone)
PTTL key                                         # Check remaining TTL (milliseconds)
PERSIST key                                      # Remove expiration (make permanent)
SETEX key 300 "value"                            # SET + EXPIRE in one command (300 seconds)
```

## 📊 Data Types

```bash
# Strings
SET counter 0                                    # Set string value
INCR counter                                     # Increment by 1
INCRBY counter 10                                # Increment by 10
DECR counter                                     # Decrement by 1
APPEND key " more"                               # Append to string
STRLEN key                                       # Get string length
MSET k1 "v1" k2 "v2" k3 "v3"                    # Set multiple keys at once
MGET k1 k2 k3                                    # Get multiple keys at once

# Hashes (objects/maps)
HSET user:1 name "John" age 30 email "j@x.com"  # Set hash fields
HGET user:1 name                                 # Get single field
HGETALL user:1                                   # Get all fields and values
HDEL user:1 email                                # Delete a field
HEXISTS user:1 name                              # Check if field exists
HKEYS user:1                                     # List all field names
HVALS user:1                                     # List all values
HLEN user:1                                      # Count fields

# Lists (ordered, duplicates allowed)
LPUSH queue "job1"                               # Push to head (left)
RPUSH queue "job2"                               # Push to tail (right)
LPOP queue                                       # Pop from head
RPOP queue                                       # Pop from tail
LRANGE queue 0 -1                                # Get all items (0 to last)
LLEN queue                                       # Get list length
LINDEX queue 0                                   # Get item at index

# Sets (unordered, unique)
SADD tags "python" "redis" "docker"              # Add members
SMEMBERS tags                                    # List all members
SISMEMBER tags "redis"                           # Check membership (1 or 0)
SCARD tags                                       # Count members
SREM tags "docker"                               # Remove member
SUNION tags1 tags2                               # Union of two sets
SINTER tags1 tags2                               # Intersection of two sets

# Sorted Sets (scored, unique)
ZADD leaderboard 100 "alice" 85 "bob" 92 "carol"  # Add with scores
ZRANGE leaderboard 0 -1 WITHSCORES              # Get all (ascending)
ZREVRANGE leaderboard 0 2 WITHSCORES            # Top 3 (descending)
ZSCORE leaderboard "alice"                       # Get score of member
ZRANK leaderboard "bob"                          # Get rank (0-based, ascending)
ZINCRBY leaderboard 5 "bob"                      # Increment score
ZCARD leaderboard                                # Count members
ZREM leaderboard "carol"                         # Remove member
```

## 📡 Pub/Sub

```bash
SUBSCRIBE channel1                               # Subscribe to channel (blocking)
PSUBSCRIBE "news:*"                              # Subscribe to pattern
PUBLISH channel1 "hello"                         # Publish message to channel
PUBSUB CHANNELS                                  # List active channels
PUBSUB NUMSUB channel1                           # Count subscribers for channel
```

## 🔍 Server and Diagnostics

```bash
INFO                                             # Full server info (memory, clients, stats)
INFO memory                                      # Memory usage details
INFO replication                                 # Replication status
INFO keyspace                                    # Database key counts
DBSIZE                                           # Key count in current database
MONITOR                                          # Watch all commands in real-time (debug only)
SLOWLOG GET 10                                   # Show 10 slowest queries
CLIENT LIST                                      # List connected clients
CLIENT KILL ID <id>                              # Disconnect a client
CONFIG GET maxmemory                             # Get config value
CONFIG SET maxmemory "256mb"                     # Set config value at runtime
LASTSAVE                                         # Timestamp of last successful save
```

## 💾 Persistence

```bash
BGSAVE                                           # Trigger background RDB snapshot
BGREWRITEAOF                                     # Trigger AOF rewrite
DEBUG SLEEP 0                                    # (test) does nothing, useful for latency testing
```

## 🧹 Flush and Cleanup

```bash
FLUSHDB                                          # Delete all keys in current database
FLUSHALL                                         # Delete all keys in ALL databases (dangerous)
OBJECT ENCODING key                              # Show internal encoding of key
MEMORY USAGE key                                 # Bytes used by key (Redis 4.0+)
```

## 🔗 Common Combos from CLI

```bash
redis-cli PING                                              # Quick health check (returns PONG)
redis-cli INFO keyspace                                     # Key counts per database
redis-cli --scan --pattern "session:*" | wc -l              # Count keys matching pattern (safe)
redis-cli --scan --pattern "cache:*" | xargs redis-cli DEL  # Delete keys matching pattern
redis-cli --bigkeys                                         # Find largest keys per type
redis-cli --memkeys                                         # Memory usage per key sampling
redis-cli --stat                                            # Live stats (ops/sec, memory, clients)
redis-cli --latency                                         # Measure latency to server
redis-cli --rdb /tmp/dump.rdb                               # Download RDB snapshot
redis-cli KEYS "temp:*" | xargs redis-cli DEL               # Bulk delete (small datasets only)
redis-cli -n 0 --scan --pattern "*" --count 1000 | head -20 # Sample keys from DB 0
```

## ⚠️ Gotchas

```bash
# KEYS "pattern" scans entire keyspace — blocks server on large DBs. Use SCAN instead.
# MONITOR tanks performance — never use in production
# FLUSHALL is not undoable — there is no confirmation prompt
# Default database is 0 — Redis has 16 DBs (0-15) but most apps only use 0
# redis-cli returns (nil) for missing keys, not an error
# TTL returns -1 (no expiry) or -2 (key doesn't exist) — check both
```
