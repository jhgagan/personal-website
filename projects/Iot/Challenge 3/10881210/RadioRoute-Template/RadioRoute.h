

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

typedef nx_struct radio_route_msg {
	//field Type
	nx_uint16_t type;
	//field Sender
	nx_uint16_t sender;
	//field Destination or Node Requested
	nx_uint16_t destination;
	//field Value
	nx_uint16_t value;
	//field cost
	nx_uint16_t cost;
	//field requested node
	nx_uint16_t req_node;
} radio_route_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
