/*jslint node: true */
"use strict";

/**
 * Module dependencies.
 */

var express = require('express')
  ,  ejs = require('ejs')
  , http = require('http')
  ;

// APPLICATION INITIALIZATION


/*
 * Setup the express middleware pipeline.
 */
var app = express();

app.set('port', 3001 );
app.set('views', __dirname);
app.set('view engine', 'html');		// default extension to use if omitted
app.engine('html', ejs.renderFile);	// Use ejs engine for routed html
app.use(app.router);				// Enables routing


//render the index page
app.get('/', function(req, res) {
	var username = (req.user && req.user.userName) ? req.user.userName : "";
	res.render('index.html'); 
});


/*
 * Startup the http server
 */
http.createServer(app).listen(app.get('port'), function(){
	console.log("YPO example application server started and listening on port " + app.get('port'));
});

         