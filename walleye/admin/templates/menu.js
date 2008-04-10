function display_admin_menu() {
		
		d = new dTree('d');
		d.config.useIcons=false;
		d.config.useLines=true;

		d.add(0,-1,'');
		d.add(1,0,'OS Administration','','Modify or administer the host OS.');
		d.add(2,1,'Clean out logging directories','osAdmin.pl?disp=cleanDir','Used to clean out old honeywall directories in order to make room for additional data.');
		d.add(3,1,'Configure SSH daemon','osAdmin.pl?disp=configSSH','Configure SSH for remote mgmt (only on the mgmt interface).');
		d.add(4,1,'Change Hostname','osAdmin.pl?disp=changeHostName','Configure hostname of the system.');
		d.add(9,1,'Configure Keyboard Layout','osAdmin.pl?disp=configKeyboard','Configure Keyboard Layout.');
		d.add(10,1,'Reboot Honeywall','osAdmin.pl?disp=rebootHoneywall','Reboot the entire system');
		
		d.add(11,0,'Honeywall Administration','','Used for the day to day administration of your configured Honeywall');
		d.add(12,11,'Manage configuration files','honeyAdmin.pl?disp=createConfig','Manage Honeywall configuration files.');
		d.add(15,11,'Emergency Lockdown','honeyAdmin.pl?disp=lockdown','Drop all traffic except to management interface.');
		d.add(17,11,'Restart Honeywall Processes','honeyAdmin.pl?disp=reload','Reload rc.firewall, snort, snort_inline.');
		d.add(19,0,'Honeywall Configuration','','Change options or variables in your Honeywall.');
		d.add(20,19,'IP Information','honeyConfig.pl?disp=configIP','Configure the gateway itself.');
		d.add(21,19,'Remote Management','honeyConfig.pl?disp=configRemote','Configure how the gateway will handle honeypot DNS requests.');
		
		d.add(22,19,'Connection Limiting','honeyConfig.pl?disp=configLimiting','Limits the number of outbound connections from Honeynet.');
		d.add(23,19,'DNS Handling','honeyConfig.pl?disp=configDNS','Configure how the gateway will handle honeypot DNS requests.');
		d.add(24,19,'Alerting','honeyConfig.pl?disp=configAlerting','Configure swatch for e-mail alerts.');
		d.add(26,19,'Honeywall Upload','honeyConfig.pl?disp=configUpload','Configure honeywall upload variables.');
		d.add(27,19,'Honeywall Summary','honeyConfig.pl?disp=configSummary','Configure honeywall traffic summary.');
		d.add(28,19,'Black and White List','honeyConfig.pl?disp=configBlackWhite','Identify a black and white list.');
		d.add(29,19,'Sebek','honeyConfig.pl?disp=configSebek','Configure how the gateway handles sebek packets.');
		d.add(32,19,'Roach Motel Mode','honeyConfig.pl?disp=configRoach','Configure Roach motel mode (restrict all outbound access from honeypots.).');	
		d.add(33,19,'Fence List','honeyConfig.pl?disp=configFence','Identify a fence list.');
		d.add(34,19,'Data Management','honeyConfig.pl?disp=configDataManagement','Data Purge.');
		d.add(35,19,'Honeynet Demographics','honeyConfig.pl?disp=configSensor','Configure Honeynet Demographics.');

		
		d.add(100,0,'System Status','','Check Honeywall\' status.');		


        d.add(101,100,'Network Interface','status.pl?act=1','Displays the current configurations/status of the network interface cards.');
        d.add(102,100,'Honeywall Config','status.pl?act=2','Displays the Honeywall configurations file.');
                d.add(103,100,'Firewall Rules','status.pl?act=3','Displays the current iptables ruleset.');
                d.add(104,100,'Running Processes','status.pl?act=4','Displays the current running processes on the Honeywall gateway.');
                d.add(105,100,'Listening Ports','status.pl?act=5','Displays LISTENing open ports.');
                d.add(106,100,'Snort_inline Alerts-fast','status.pl?act=6','Displays any alerts generated for that day by Snort-Inline (fast mode).');
                d.add(107,100,'Snort_inline Alerts-full','status.pl?act=7','Displays any alerts generated for that day by Snort-Inline (full mode).');
                d.add(108,100,'Snort Alerts','status.pl?act=8','Displays any alerts generated that day by Snort.');
                d.add(109,100,'System Logs','status.pl?act=9','Displays system logs (/var/log/messages).');
                d.add(110,100,'Inbound Connections','status.pl?act=10','Looks for Inbound Connections in Honeywall Logs.');
                d.add(111,100,'Outbound Connections','status.pl?act=11','Looks for Outbound Connections in Honeywall Logs.');
                d.add(112,100,'Dropped Connections','status.pl?act=12','Connections that have been dropped because the limit has been reached.');
                d.add(113,100,'tcpdstat Traffic Statistics','status.pl?act=13','Statistics for Snort traffic captures.');
                d.add(114,100,'Argus Flow Summaries','status.pl?act=14','Flow Summaries for Snort traffic captures.');
                d.add(115,100,'Tracked Connections','status.pl?act=15','Connections Currently Tracked by iptables');
	d.add(300,0,'Manage Users','userList.pl');


		document.write(d);

}

function display_customize_iso_menu() {
		
	d = new dTree('d');
	d.config.useIcons=false;
	d.config.useLines=true;

	d.add(0,-1,'');
	d.add(10,0,'Unpack iso','customizeIso.pl?disp=unpackIso','Unpack roo iso.');
	d.add(20,0,'Honeywall Configuration','customizeIso.pl?disp=conf','Customize honeywall.conf file.');
	d.add(30,0,'Manage Passwords','');
	d.add(40,30,'Change User Passwords','customizeIso.pl?disp=changePassword','Create new passwords for roo users');
	d.add(50,30,'Remove Changed User Passwords','customizeIso.pl?disp=removePassword','Remove created passwords for roo users');
	d.add(60,0,'SSH Files','');
	d.add(70,60,'Upload SSH Files','customizeIso.pl?disp=uploadSsh','Upload ssh keys and files.');
	d.add(80,60,'Remove SSH Files','customizeIso.pl?disp=removeSsh','Dislpay or remove ssh files.');
	d.add(90,0,'User Files','');
	d.add(100,90,'Upload Files to User Directories','customizeIso.pl?disp=uploadUser','Upload files to user directories');
	d.add(110,90,'Remove Users files','customizeIso.pl?disp=removeUser','Display or remove files in users directories.');
	d.add(120,0,'Walleye Files','');
	d.add(130,120,'Upload Files to Customize Walleye','customizeIso.pl?disp=uploadWalleye','Upload files to Walleye directory');
	d.add(140,120,'Remove Walleye files','customizeIso.pl?disp=removeWalleye','Display or remove files in Walleye directory.');


	document.write(d);

}
