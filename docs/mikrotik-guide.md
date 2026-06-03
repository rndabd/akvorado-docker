# MikroTik to Akvorado Configuration Guide

## Prerequisites

- MikroTik router with RouterOS 6.x or 7.x
- Network access from MikroTik to Akvorado server
- SNMP enabled on MikroTik

## Quick Setup

### 1. Enable NetFlow (Traffic Flow)

```routeros
# Enable traffic-flow
/ip traffic-flow
set enabled=yes

# Add Akvorado as target
# Replace AKAVERADO_IP with your Akvorado server IP
/ip traffic-flow target
add dst-address=AKVORADO_IP port=2055 version=9
```

### 2. Enable SNMP

```routeros
# Enable SNMP
/snmp
set enabled=yes

# Configure community string
# Replace "public" with your community string
/snmp community
set [find name=public] write-access=yes
```

### 3. Verify Configuration

```routeros
# Check traffic-flow status
/ip traffic-flow print

# Check traffic-flow targets
/ip traffic-flow target print

# Check SNMP status
/snmp print

# Check SNMP communities
/snmp community print
```

## Advanced Configuration

### NetFlow v9 Template Refresh

```routeros
/ip traffic-flow
set enabled=yes
set template-refresh=20
set template-timeout=30m
```

### Sampling (for high-traffic routers)

```routeros
/ip traffic-flow
set enabled=yes
set packet-sampling=yes
set sampling-interval=100
set sampling-space=100
```

### Interface-specific Flow

```routeros
# Only monitor specific interfaces
/ip traffic-flow
set enabled=yes
set interfaces=ether1,ether2
```

## MikroTik Interface Naming

For Akvorado to properly classify interfaces, use descriptive names:

```routeros
# Rename interfaces
/interface ethernet
set [find name=ether1] name=ether1-WAN
set [find name=ether2] name=ether2-LAN
```

### Interface Description Convention

Akvorado uses interface descriptions to classify traffic:

- **WAN** interfaces: Classified as **external/transit**
- **LAN** interfaces: Classified as **internal/pni**

```routeros
# Set interface descriptions
/interface ethernet
set [find name=ether1-WAN] comment="Transit: ISP Upstream"
set [find name=ether2-LAN] comment="PNI: Customer Network"
```

## Firewall Rules

Ensure NetFlow traffic can reach Akvorado:

```routeros
# Allow NetFlow to Akvorado
/ip firewall filter
add chain=output protocol=udp dst-address=AKVORADO_IP dst-port=2055 action=accept comment="NetFlow to Akvorado"
add chain=output protocol=udp dst-address=AKVORADO_IP dst-port=4739 action=accept comment="IPFIX to Akvorado"
add chain=output protocol=udp dst-address=AKVORADO_IP dst-port=6343 action=accept comment="sFlow to Akvorado"

# Allow SNMP from Akvorado
/ip firewall filter
add chain=input protocol=udp src-address=AKVORADO_IP dst-port=161 action=accept comment="SNMP from Akvorado"
```

## Multiple MikroTik Routers

### Router 1 (Core)
```routeros
/ip traffic-flow
set enabled=yes
/ip traffic-flow target
add dst-address=AKVORADO_IP port=2055 version=9

/interface ethernet
set [find name=ether1] name=ether1-WAN
set [find name=ether2] name=ether2-LAN-Core
```

### Router 2 (Edge)
```routeros
/ip traffic-flow
set enabled=yes
/ip traffic-flow target
add dst-address=AKVORADO_IP port=2055 version=9

/interface ethernet
set [find name=ether1] name=ether1-WAN-Backup
set [find name=ether2] name=ether2-LAN-Edge
```

## SNMP v3 Configuration (Recommended)

For production environments, use SNMPv3:

```routeros
# Create SNMPv3 user
/snmp
set enabled=yes

/snmp community
add name=akvorado addresses=AKVORADO_IP/32 read-access=yes write-access=no
set [find name=public] addresses=AKVORADO_IP/32
```

Then update Akvorado configuration:

```yaml
# config/outlet.yaml
metadata:
  providers:
    - type: snmp
      ports:
        ::/0: 161
      credentials:
        ::/0:
          communities: akvorado
```

## Troubleshooting

### Check if NetFlow is sending

```routeros
# Check traffic-flow statistics
/ip traffic-flow print stats

# Check if flows are being generated
/ip traffic-flow cache print
```

### Check SNMP connectivity

```routeros
# Test SNMP from MikroTik
/snmp
set enabled=yes

# Check SNMP logs
/log print where topics~"snmp"
```

### Common Issues

1. **No flows in Akvorado**
   - Check firewall rules
   - Verify NetFlow target IP and port
   - Check if traffic-flow is enabled

2. **SNMP timeout**
   - Verify SNMP community string
   - Check firewall rules for UDP port 161
   - Ensure SNMP is enabled on MikroTik

3. **Interface classification not working**
   - Use proper interface naming (WAN/LAN)
   - Set interface descriptions
   - Check outlet.yaml classifiers

## Example: Complete MikroTik Configuration

```routeros
# System identity
/system identity
set name=Router-Akvorado

# Enable NetFlow
/ip traffic-flow
set enabled=yes
/ip traffic-flow target
add dst-address=192.168.1.100 port=2055 version=9

# Enable SNMP
/snmp
set enabled=yes
/snmp community
set [find name=public] addresses=192.168.1.100/32

# Interface naming
/interface ethernet
set [find name=ether1] name=ether1-WAN
set [find name=ether2] name=ether2-LAN

# Firewall rules
/ip firewall filter
add chain=output protocol=udp dst-address=192.168.1.100 dst-port=2055 action=accept
add chain=input protocol=udp src-address=192.168.1.100 dst-port=161 action=accept

# Verify
/ip traffic-flow print
/ip traffic-flow target print
/snmp print
/snmp community print
```

## Cisco/Juniper/Other Routers

### Cisco IOS
```
flow exporter AKVORADO
  destination 192.168.1.100
  transport udp 2055

flow monitor AKVORADO-MON
  exporter AKVORADO
  record netflow ipv4

interface GigabitEthernet0/0/0
  ip flow monitor AKVORADO-MON input
  ip flow monitor AKVORADO-MON output
```

### Juniper JunOS
```
set protocols sflow collector 192.168.1.100 udp-port 6343
set protocols sflow interfaces ge-0/0/0
```

### Huawei VRP
```
sflow collector ip 192.168.1.100 port 6343
sflow agent ip 192.168.1.1
sflow interface GigabitEthernet0/0/0
```
