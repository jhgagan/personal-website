from scapy.all import *
from scapy.layers.inet import IP
from scapy.layers.l2 import Ether
from scapy.contrib.coap import CoAP

packets = rdpcap('D:\Master Courses\Internet of Things\Labs\Challenge 1 code\Packet_list.pcap')
for packet in packets:
    if packet.haslayer(IP) and packet.haslayer(Ether):
        if packet[IP].proto == 17:
            if packet[IP].dport == 5683 or packet[IP].sport == 5683:
                print("Message ID: ", packet[CoAP].mid)
                print(packet.show())
                print('Done')