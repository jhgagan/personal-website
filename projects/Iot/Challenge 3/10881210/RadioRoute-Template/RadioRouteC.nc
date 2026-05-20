
/*
*	IMPORTANT:
*	The code will be evaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "RadioRoute.h"
#include <math.h>

module RadioRouteC @safe() {
  uses {
  
    /****** INTERFACES *****/
	interface Boot;

    //interfaces for communication
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
	
	//interface for timers
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;
	
	
	//interface for LED
	interface Leds;
	
    //other interfaces, if needed
    interface Packet;
  }
}
implementation {

  message_t packet;
  
  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  uint16_t addrs;
  
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  
  bool led_0, led_1, led_2;
  
  
  bool locked;
  bool broadcast;
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  
  // Person Code
  uint8_t reg_num[8] = {1,0,8,8,1,2,1,0};
  
  uint8_t count = 0;
  
  //variables required
  uint8_t type;
  uint8_t sender;
  uint8_t destination;
  uint8_t value;
  uint8_t cost;
  uint8_t req_node;
  
  //routing table
  int rtDestination[6];
  int rtNextHop[6];
  int rtCost[6];
  int i;
  bool found = FALSE;
  
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  	route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }
  
  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  bool actual_send (uint16_t address, message_t* packet){
	/*
	* Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
	*/
	 /* if(call AMSend.send(address, &packet, sizeof(radio_route_msg_t)) == SUCCESS) {
		//packet sent successfully
		dbg("radio", "size of packet: %hhu \n", sizeof(radio_route_msg_t));
	
		dbg("radio","Packet sent Successfully by %hhu at time %s \n(From actual send) \n",TOS_NODE_ID, sim_time_string());
		// we will also be locking the radio to make sure we don't recieve a message while we are sending this message.
		locked = TRUE;
	}
	else{
		dbg("radio", "packet not sent\n");
	}
	  */
  }
  
  
  event void Boot.booted() {
    dbg("boot","Application booted.%hhu \n", TOS_NODE_ID);
    /* Once the mote sucessfully boots. We will enable the radio.*/
    call AMControl.start();
	
	dbg("boot", "All the leds are in the off state\n");
	// setting all the leds to turned off state
	call Leds.led0Off();
	led_0 = FALSE;
	call Leds.led1Off();
	led_1 = FALSE;
	call Leds.led2Off();
	led_2 = FALSE;
	
    // set all the values of the routing table to 0
    for(i = 0; i < 6; i++)
    {
    	rtDestination[i] = 0;
    	rtNextHop[i] = 0;
  		rtCost[i] = 0;
    }
    
    if(TOS_NODE_ID == 2)
    {
    	rtDestination[0] = 4;
    	rtNextHop[0] = 4;
    	rtCost[0] = 1;
    }
    dbg("init", "Initialized the routing table for node %hhu .\n",TOS_NODE_ID);
  }

  event void AMControl.startDone(error_t err) {
	/* Here we have to check if the radio started sucessfully. If the radio failed 
	to start sucessfully we need to try again */
	if( err == SUCCESS)
	{
		dbg("radio", "Radio Started Successfully.\n");
		// use a one shot timer to fire after 5 sec (5000 milli seconds)
		if(TOS_NODE_ID == 1)
		{
			// Start the timer if the current mote's address is 1.
			dbg("timer", "Timer Started Successfully.\n");
			call Timer1.startOneShot(call Timer1.getNow()+5100);
		}
		
	}
	else{
		dbg("radio", "Radio Failed to Start.\n");
		dbg("radio", "Attempting to Start Radio Again.\n");
		call AMControl.start();
  }
}
  event void AMControl.stopDone(error_t err) {
    /* Fill it ... */
  }
  
  event void Timer1.fired() {
	/*
	* Implement here the logic to trigger the Node 1 to send the first REQ packet
	*/
	dbg("timer","Timer1 fired at time: %s\n", sim_time_string());
	/* Now we need to check the address of the current mote. If the current mote address is 
	1 then we need to send the message with value 5 to node 7 else we don't do anything.*/ 
	if(TOS_NODE_ID == 1 && route_req_sent == FALSE)
	{
		
		/*
		Because the address of the current mote is 1 we need to send a message to mote 7.
		
		Before that we need to find the route to mote 7 This is done by first sending a
		route request.
		
		So, first we need to check if the radio is available.

		We also need to pass the payload to the message.		
		*/
		radio_route_msg_t* rrmsg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
		// Checking if the message is empty
		if(rrmsg == NULL)
		{
		return;
		}
		
		// now we add the contents to the message
		// setting the message type to 1 i.e., ROUTE_REQ.
		rrmsg->type = 1;
		// setting the sender address to 1
		rrmsg->destination = 7;
		// setting the requested node address to 7
		rrmsg->req_node = 7;
		// setting the sender address to TOS_NODE_ID
		rrmsg->sender = TOS_NODE_ID;
		
		// Now we need to broadcast the route request to all the motes.
		// We also check if the packet is sent successfully.
		if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_route_msg_t)) == SUCCESS) {
			//packet sent successfully
			dbg("radio","RadioRoteC: Packet sent Successfully by %hhu at time %s \n",TOS_NODE_ID, sim_time_string());
			// we will also be locking the radio to make sure we don't recieve a message while we are sending this message.
			locked = TRUE;
			// we also set the route_req_sent to TRUE.
			route_req_sent = TRUE;
		}
	}	
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	* Parse the receive packet.
	* Implement all the functionalities
	* Perform the packet send using the generate_send function if needed
	* Implement the LED logic and print LED status on Debug
	*/
	
	//dbg("radio_rec", "Received packet of len %hhu.\n", len);
	
	// LED blink logic
	
		// print the led status only of the node 6
	if(TOS_NODE_ID == 6)
	{
		switch((reg_num[count%8]%3))// this switch case is used to find which led to toggle based on my person code
		{
			case 0:
			dbg("led_0", "LED 0 Toggled\n");
			dbg_clear("led_0", "\t\t Reg_num digit: %hhu\n", reg_num[count%8]);
			dbg_clear("led_0", "\t\t LED number: %hhu\n", (reg_num[count%8]%3));
			call Leds.led0Toggle();
			led_0 = !led_0;
			break;
			
			case 1:
			dbg("led_1", "LED 1 Toggled\n");
			dbg_clear("led_1", "\t\t Reg_num digit: %hhu\n", reg_num[count%8]);
			dbg_clear("led_1", "\t\t LED number: %hhu\n", (reg_num[count%8]%3));
			led_1 = !led_1;
			call Leds.led1Toggle();
			break;
			
			case 2:
			dbg("led_2", "LED 2 Toggled\n");
			dbg_clear("led_2", "\t\t Reg_num digit: %hhu\n", reg_num[count%8]);
			dbg_clear("led_2", "\t\t LED number: %hhu\n", (reg_num[count%8]%3));
			call Leds.led0Toggle();
			led_2 = !led_2;
			break;
		}
		//dbg_clear("led_status","\n \t\t count: %hhu\n", count);
		count+=1;	// this keep a count of the number of messages recieved per node
			
			
		// checks and prints the status of led0
		if(led_0)
		{
			dbg_clear("led_status", "1");
		}
		else
		{
			dbg_clear("led_status", "0");
		}
		// checks and prints the status of led1
		if(led_1)
		{
			dbg_clear("led_status", "1");
		}
		else
		{
			dbg_clear("led_status", "0");
		}
		// checks and prints the status of led2
		if(led_2)
		{
			dbg_clear("led_status", "1, ");
		}
		else
		{
			dbg_clear("led_status", "0, ");
		}
	}
	
	
	// packet analysis section
	if( len != sizeof(radio_route_msg_t)){return bufPtr;}
	else {
		//Forwarding the received packets
		radio_route_msg_t* rrmsg = (radio_route_msg_t*)payload;
		dbg("radio", "received type: %hhu \n", rrmsg->type);
		type = rrmsg->type;
			//Check the received packet type
			if(type == 0)	//DATA_PACKET
			{
				// Data Message
				sender = rrmsg->sender;
				destination = rrmsg->destination;
				req_node = rrmsg->req_node;
				cost = rrmsg->cost;
				value = rrmsg->value;
				// Check if the data message is directed for the current node
				if(destination == TOS_NODE_ID)
				{
					dbg("radio_rec", " Data packet received at node %hhu sent by %hhu.\n", destination, rrmsg->sender);
					dbg_clear("radio_rec", "\t\tvalue : %hhu\n", rrmsg->value);
					broadcast = FALSE;
				}
				else
				{
					dbg("radio_rec", " Data packet has to be send further to a particular node.\n");
					dbg_clear("radio_rec","\t\t Payload \n" );
      				dbg_clear("radio_rec", "\t\t Type: %hhu \n",rrmsg->type);
      				dbg_clear("radio_rec", "\t\t Sender: %hhu \n",rrmsg->sender);
      				dbg_clear("radio_rec", "\t\t Requested node: %hhu \n",rrmsg->req_node);
      				dbg_clear("radio_rec", "\t\t Destination: %hhu \n",rrmsg->destination);
      				broadcast = FALSE;
      				
      				for(i = 0; i<6; i++)
      				{
      					if(destination == rtDestination[i])
      					{
      						addrs = rtNextHop[i];
      						break;
      					}
      				}
      				
      				// parsing the data to the next node
      				rrmsg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      				
      				rrmsg->type = type;
      				rrmsg->sender = sender;
      				rrmsg->destination = destination;
      				rrmsg->req_node = req_node;
      				rrmsg->cost = cost;
      				rrmsg->value = value;
      				
      				generate_send(addrs, &packet, type);
      				
      				
				}
			}
			else if (type == 1 ) //ROUTE_REQUEST
			{
				// Print the important information to make it easier to debug
				dbg("radio_rec", "Route Request Message Received at %hhu by %hhu.\n", TOS_NODE_ID, rrmsg->sender);
      			
      			// Data Message
				sender = rrmsg->sender;
				destination = rrmsg->destination;
				req_node = rrmsg->req_node;
				cost = rrmsg->cost;
				    
				    
				    dbg_clear("radio_rec","\t\t Payload \n" );
      				dbg_clear("radio_rec", "\t\t Type: %hhu \n",type);
      				dbg_clear("radio_rec", "\t\t Sender: %hhu \n",sender);
      				dbg_clear("radio_rec", "\t\t Requested node: %hhu \n",req_node);
      				dbg_clear("radio_rec", "\t\t Destination: %hhu \n",destination);
				
      			
      			// check if the requested node is reached
      			if(rrmsg->req_node == TOS_NODE_ID)
      			{
      				dbg("radio_rec","Requested node received the Route request.\n");
      				dbg("radio_rec","Sending route reply. (ROUTE_REQUEST)\n");
      				
      				
      				dbg_clear("radio_rec","\t\t Payload \n" );
      				dbg_clear("radio_rec", "\t\t Type: %hhu \n",rrmsg->type);
      				dbg_clear("radio_rec", "\t\t Sender: %hhu \n",rrmsg->sender);
      				dbg_clear("radio_rec", "\t\t Requested node: %hhu \n",rrmsg->req_node);
      				dbg_clear("radio_rec", "\t\t Destination: %hhu \n",rrmsg->destination);
      				
      				rrmsg = (radio_route_msg_t*)payload;
			
					// creating the route reply message
      				type = 2;
      				req_node = req_node;
      				destination = sender;
      				sender = TOS_NODE_ID;
      				cost = 1;
      				broadcast = TRUE;
      				addrs = AM_BROADCAST_ADDR;
      				
      			}
      			else if (sender != TOS_NODE_ID)
      			{
      				found = FALSE;
      				for(i = 0; i < 6;i++)
      				{
      					if(rtDestination[i] == req_node)
      					{
      						dbg("radio", "Route present in the routing table.\n");
      						type = 2;
      						cost = rtCost[i]+1;
      						sender = TOS_NODE_ID;
      						destination = rrmsg->sender;
      						req_node = req_node; // doesn't change
      						broadcast = TRUE;
      						found = TRUE;
      						addrs = AM_BROADCAST_ADDR;
      					}	
      				}
      				

      				if(found == FALSE)
      				{
      					dbg("radio", "Need to check the cost of the existing route and update the routing table.(ROUTE_REQUEST)\n");
      					dbg("radio", "Broadcasting further.\n");
      				
      					
			
						// creating the route reply message
      					type = 1;
      					req_node = req_node;
      					destination = destination;
      					sender = sender;
      					cost = 0;
      					broadcast = TRUE;
      					addrs = AM_BROADCAST_ADDR;
      				}
      				
      				
      			}
			}
			else if (type == 2)	//ROUTE_REPLY
			{
				// Printing the important information to make it easier to debug
				dbg("radio_rec", "Route Reply Packet Received at %hhu by %hhu.\n", TOS_NODE_ID, rrmsg->sender);
				dbg_clear("radio_rec","\t\t Payload \n" );
      			dbg_clear("radio_rec", "\t\t Type: %hhu \n",rrmsg->type);
      			dbg_clear("radio_rec", "\t\t Sender: %hhu \n",rrmsg->sender);
      			dbg_clear("radio_rec", "\t\t Requested node: %hhu \n",rrmsg->req_node);
      			dbg_clear("radio_rec", "\t\t Destination: %hhu \n",rrmsg->destination);
      			dbg_clear("radio_rec", "\t\t Cost: %hhu \n",rrmsg->cost);
      			// Data Message
				type = rrmsg->type;
				sender = rrmsg->sender;
				destination = rrmsg->destination;
				req_node = rrmsg->req_node;
				cost = rrmsg->cost;
				
				if(destination == TOS_NODE_ID)
				{
					dbg("radio_rec", "Route reply received at the sender node %hhu.\n", TOS_NODE_ID);
					found = FALSE;
					for(i =0; i<6; i++)
					{
						if(rtDestination[i] == rrmsg->req_node && found == FALSE)
						{
							found == TRUE;
							if(cost < rtCost[i])
							{
								dbg("radio", "updated the routing table with the path of lower cost.\n");
								rtCost[i] == cost;
								rtNextHop[i] == rrmsg->sender;
								
								// creating the route reply message
      							type = 2;
      							req_node = req_node;
      							destination = destination;
      							sender = TOS_NODE_ID;
      							cost = cost+1;
      							broadcast = FALSE;
      							addrs = AM_BROADCAST_ADDR;
      						}
						}
						if(rtDestination[i] == 0 && found == FALSE)// empty slot in the Routing table
						{
						
							dbg("radio", "new Path received. adding to RT (reply).\n");

							found == TRUE;
							rtDestination[i] = rrmsg->req_node;
							rtNextHop[i] = rrmsg->sender;
							rtCost[i] = rrmsg->cost;
							
							// creating the route reply message
      						type = 2;
      						req_node = req_node;
      						destination = destination;
      						sender = TOS_NODE_ID;
      						cost = cost+1;
      						broadcast = FALSE;
      						addrs = AM_BROADCAST_ADDR;
							
						}
						
					}
					
					if(found == TRUE)
					{
						for(i = 0; i<6; i++)
						{
							dbg("radio_rec","\t\t %hhu \t %hhu \t %hhu \n",rtDestination[i], rtNextHop[i], rtCost[i]);
						}
					}
					
				}
				else if (TOS_NODE_ID == rrmsg->req_node)
				{
					dbg("radio","Do nothing because this is the requested node.\n");
				}
				else
				{
					dbg("radio_rec", "Have to check the routing table if a route is available... (ROUTE_REPLY)\n");
					// increment the cost and broadcast it 
					found == FALSE;
					for(i =0; i<6; i++)
					{
						if(rrmsg->req_node == rtDestination[i] && found == FALSE)//checking the routing table
						{
							// Present in the routing table so comparing which has lesser cost 
							found == TRUE;
							if(cost < rtCost[i])
							{
								dbg("radio", "updated the routing table with the path of lower cost.\n");
								rtCost[i] == cost;
								rtNextHop[i] == rrmsg->sender;
								
								// creating the route reply message
      							type = 2;
      							req_node = req_node;
      							destination = destination;
      							sender = TOS_NODE_ID;
      							cost = cost+1;
      							broadcast = TRUE;
      							addrs = AM_BROADCAST_ADDR;
							}
							else
							{
								dbg("radio", "cost of the path present is better than the recieved path.\n");
							}
							
							
						}
						// not present in the routing table so adding to the routing table
						if(rtDestination[i] == 0 && found == FALSE)
						{
						
						dbg("radio", "new Path received. adding to RT.\n");
							found == TRUE;
							rtDestination[i] = rrmsg->req_node;
							rtNextHop[i] = rrmsg->sender;
							rtCost[i] = rrmsg->cost;
							
							// creating the route reply message
      						type = 2;
      						req_node = req_node;
      						destination = destination;
      						sender = TOS_NODE_ID;
      						cost = cost+1;
      						broadcast = TRUE;
      						addrs = AM_BROADCAST_ADDR;
							
						}
					}
					
					
					dbg("radio", "Broadcasting further.\n");
			

      			}
			
					
			}

	 		//generate_send(7, &rrmsg , 1);
	 		
	 		rrmsg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      				
      		rrmsg->type = type;
      		rrmsg->sender = sender;
      		rrmsg->destination = destination;
      		rrmsg->req_node = req_node;
      		rrmsg->cost = cost;
	 		
	 		if(found == TRUE)
	 		{
	 			for(i = 0; i < 6 ; i++)
	 			{
	 				dbg("radio_rec","\t\t %hhu \t %hhu \t %hhu \n",rtDestination[i], rtNextHop[i], rtCost[i]);
	 			}
	 		}
	 		
	 		//generate_send(addrs, &packet , type);
	 		
	 		if(broadcast == TRUE && ((route_req_sent == FALSE && type == 1)||(route_rep_sent == FALSE && type == 2)))
	 		{
	 		

	 			// Checking if the message is empty
					if(rrmsg == NULL)
					{
						dbg("radio", "NULL message.\n");
						return;
					}
					
					
      				
      				dbg("radio", "Values before broadcasting. (broadcast section)\n");
					dbg_clear("radio_rec","\t\t Payload \n" );
      				dbg_clear("radio_rec", "\t\t Type: %hhu \n",rrmsg->type);
      				dbg_clear("radio_rec", "\t\t Sender: %hhu \n",rrmsg->sender);
      				dbg_clear("radio_rec", "\t\t Requested node: %hhu \n",rrmsg->req_node);
      				dbg_clear("radio_rec", "\t\t Destination: %hhu \n",rrmsg->destination);
      				dbg_clear("radio_rec", "\t\t Cost: %hhu \n",rrmsg->cost);
      				
      				
      				if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_route_msg_t)) == SUCCESS)
      				{
						//packet sent successfully
						dbg("radio_sent","Packet sent Successfully by %hhu at time %s \n",TOS_NODE_ID, sim_time_string());
						// we will also be locking the radio to make sure we don't recieve a message while we are sending this message.
						locked = TRUE;
						// we also set the route_req_sent to TRUE.
						if(type == 1)
						{
							route_req_sent = TRUE;
						}
						else if(type = 2)
						{
							route_rep_sent = TRUE;
						}
					}
					else
					{
						dbg("radio","Packet not getting sent!!!.\n");
					}
					broadcast = FALSE;
	 		}
  		}
    
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
	if (&packet == bufPtr) {
		// When the packet has been sent we need to set the locked variable to false, this 			denotes that the radio is now free to send or recieve.
      	locked = FALSE;
    }
  }
}

