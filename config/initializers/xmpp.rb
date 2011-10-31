@@xmpp_host = "nota.cs.tut.fi"
@@xmpp_port = 5222
@@xmpp_xml_dtd = "public/dtd/xmpp2rest_api.dtd"




# Environment specific:

# Client that is used to send xmpp-messages
@@xmpp_send_id = "change_this"
@@xmpp_send_password = "change_this"

# Client that is used to receive xmpp-messages (xmpp2rest)
@@xmpp_receive_id = "change_this"
@@xmpp_receive_password = "change_this"

@@xmpp_node_id = "change_this"
@@xmpp_node_password = "change_this"

# Environment specific ends..

@@xmpp_send_account =  @@xmpp_send_id + '@' + @@xmpp_host + "/main"
@@xmpp_receive_account =  @@xmpp_receive_id + '@' + @@xmpp_host + "/main"
@@xmpp_node_account = @@xmpp_node_id + '@' + @@xmpp_host

@@send_client_info = {:id => @@xmpp_send_account, :psword => @@xmpp_send_password,
                      :host => @@xmpp_host, :port => @@xmpp_port}


@@receive_client_info = {:id => @@xmpp_receive_account, :psword => @@xmpp_receive_password,
                         :host => @@xmpp_host, :port => @@xmpp_port}

@@node_client_info = {:id => @@xmpp_node_account, :psword => @@xmpp_node_password,
                      :host => @@xmpp_host, :port => @@xmpp_port, :plain_id => @@xmpp_node_id, 
                      :node_service => "pubsub.#{@@xmpp_host}"}


@@http_host = "http://localhost:8443"




















