# Setting up a NAT Switch for TestLabs in  Hyper-V Server 2016 or Windows 10	
New-VMSwitch –SwitchName "NATSwitch” –SwitchType Internal 
New-NetIPAddress –IPAddress 172.16.0.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)" 
New-NetNat –Name NATNetwork –InternalIPInterfaceAddressPrefix 172.16.0.0/24