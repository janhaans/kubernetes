# Networking

## Switches

A switch connects host in one network.

Show the interfaces on a Linux system

`ip link`

Show the ip addressed associated to interfaces

`ip addr`

Add ip address `192.168.1.10` of network `192.168.1.0/24` to interface `eth0`

`ip addr add 192.168.1.10/24 dev eth0`

Tp persist this change you must set the IP address in the `/etc

## Routers

A router connects networks

Show the routes on a Linux system

`route`

Add on Linux host a route to route traffic to network `192.168.2.0/24` via gateway `192.168.1.1` (router's IP address)

`ip route add 192.168.2.0/24 via 192.168.1.1`

Or add on Linux host a route to route traffic to any network via gateway `192.168.1.1` (router's IP address). This is the default gateway

`ip route add default via 192.168.1.1`

A linux host can act as an router by forwarding IP packets from for example interface `eth0`, that is connected to network `192.168.1.0/24`, to interface `eth1`, that is connected to network `192.168.2.0/24`:

```
cat /proc/sys/net/ipv4/ip_forward

if output is 0, then no IP forwarding, then do:

echo 1 > /proc/sys/net/ipv4/ip_forward

to enable IP forwarding after reboot change file /etc/sysctl.conf to:
...
net.ipv4.ip_forward = 1
...
```

## DNS

- Local name resolution defined in file `/etc/hosts`
- Remote name resolution by DNS server defined in file `/etc/resolve.conf`

```
...
nameserver  192.168.1.100   # private DNS
nameserver  8.8.8.8         # public Google DNS or you can configure private DNS to forward unknown names
                            # to Google DNS, then you do not need this entry
...
```

- Order of resolution defined in file `/etc/nsswitch.conf`

```
...
hosts:   files dns
...
```

A server can be turned into a DNS servers by installing [coreDNS](https://github.com/coredns/coredns). A DNS server has records that translate IP adresses into names (`A` (IPv4) and `AAAA` (IPv6) records) and names into other names (aliases or `CNAME` records)

## Network Namespaces

Create network namespace named `red`

`ip netns add red`

List all network namespaces

`ip netns`

List network interfaces and routing table in `red` network namespace

```
ip netns exec red ip link
ip netns exec red route
```

To create two network namespaces (red and blue) and set up a virtual link between them on a Linux system, you can follow these steps. This will use ip commands from the iproute2 package, which is commonly available on modern Linux distributions.

```
# Create namespaces
sudo ip netns add red
sudo ip netns add blue

# Create a virtual ethernet pair
sudo ip link add veth-red type veth peer name veth-blue

# Assign interfaces to the namespaces
sudo ip link set veth-red netns red
sudo ip link set veth-blue netns blue

# Assign IP addresses and bring interfaces up
sudo ip netns exec red ip addr add 192.168.15.1/24 dev veth-red
sudo ip netns exec red ip link set veth-red up
sudo ip netns exec blue ip addr add 192.168.15.2/24 dev veth-blue
sudo ip netns exec blue ip link set veth-blue up

# Bring up loopback interfaces
sudo ip netns exec red ip link set lo up
sudo ip netns exec blue ip link set lo up

# Test connectivity
sudo ip netns exec red ping 192.168.15.2
sudo ip netns exec blue ping 192.168.15.1
```

To connect the red and blue network namespaces via a virtual bridge, we will set up a virtual bridge interface (br0) and attach the virtual Ethernet interfaces from both namespaces to the bridge. This will allow the red and blue namespaces to communicate through the bridge, much like devices connected to a physical switch.

```
# Create namespaces
sudo ip netns add red
sudo ip netns add blue

# Create a virtual bridge
sudo ip link add name br0 type bridge

# Create veth pairs
sudo ip link add veth-red type veth peer name veth-red-br
sudo ip link add veth-blue type veth peer name veth-blue-br

# Move one end of each veth pair into the namespaces
sudo ip link set veth-red netns red
sudo ip link set veth-blue netns blue

# Attach the other ends to the bridge
sudo ip link set veth-red-br master br0
sudo ip link set veth-blue-br master br0

# Bring up the bridge and veth interfaces on the host
sudo ip link set br0 up
sudo ip link set veth-red-br up
sudo ip link set veth-blue-br up

# Configure the red namespace
sudo ip netns exec red ip addr add 192.168.15.1/24 dev veth-red
sudo ip netns exec red ip link set veth-red up
sudo ip netns exec red ip link set lo up

# Configure the blue namespace
sudo ip netns exec blue ip addr add 192.168.15.2/24 dev veth-blue
sudo ip netns exec blue ip link set veth-blue up
sudo ip netns exec blue ip link set lo up

# Test connectivity
sudo ip netns exec red ping 192.168.15.2
sudo ip netns exec blue ping 192.168.15.1
```

To allow the blue network namespace to connect to the external world, you need to configure network address translation (NAT) on the host machine. This involves enabling IP forwarding, creating a default route for the blue namespace, and configuring iptables to masquerade outgoing traffic from blue so that it appears to come from the host’s IP address.

```
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Add IP address to the bridge's interface connected to blue
sudo ip addr add 192.168.15.254/24 dev veth-blue-br
sudo ip link set veth-blue-br up

# Set default route in blue namespace
sudo ip netns exec blue ip route add default via 192.168.15.254

# Configure iptables for NAT masquerading
sudo iptables -t nat -A POSTROUTING -s 192.168.15.0/24 -o eth0 -j MASQUERADE

# Test connectivity from blue namespace
sudo ip netns exec blue ping 8.8.8.8
```

To allow the external world to access services running inside the blue namespace, you will need to configure port forwarding on the host machine. This involves:

1. Forwarding traffic from a specific port on the host to the blue namespace.
2. Ensuring the necessary firewall (iptables) rules are in place to route traffic into the blue namespace.
3. Making sure the service running in the blue namespace is listening on the appropriate interface.

```
# Start an HTTP server inside the blue namespace (optional)
sudo ip netns exec blue python3 -m http.server 80 --bind 192.168.15.2

# DNAT Rule: Add iptables rule to forward traffic from host's port 8080 to blue's port 80
sudo iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 8080 -j DNAT --to-destination 192.168.15.2:80

# Forwarding Rule: Allow forwarded traffic in the FORWARD chain
sudo iptables -A FORWARD -p tcp -d 192.168.15.2 --dport 80 -j ACCEPT

# Enable IP forwarding if necessary
sudo sysctl -w net.ipv4.ip_forward=1
```
