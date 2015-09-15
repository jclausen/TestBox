/**
********************************************************************************
Copyright Since 2005 TestBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.ortussolutions.com
********************************************************************************
* This is a base spec object that is used to test XUnit and BDD style specification methods
*/
component{

	// MockBox mocking framework
	variables.$mockBox = this.$mockBox 	= new testbox.system.MockBox();
	// Assertions object
	variables.$assert = this.$assert = new testbox.system.Assertion();
	// Custom Matchers
	this.$customMatchers 		= {};
	// Utility object
	this.$utility 				= new testbox.system.util.Util();
	// BDD Test Suites are stored here as an array so they are executed in order of definition
	this.$suites 				= [];
	// A reverse lookup for the suite definitions
	this.$suiteReverseLookup	= {};
	// The suite context
	this.$suiteContext			= "";
	// ExpectedException Annotation
	this.$exceptionAnnotation	= "expectedException";
	// Expected Exception holder, only use on synchronous testing.
	this.$expectedException		= {};
	// Internal testing ID
	this.$testID 				= createUUID();
	// Debug buffer
	this.$debugBuffer			= [];
	// Current Executing Spec
	this.$currentExecutingSpec 	= "";

	/************************************** BDD & EXPECTATIONS METHODS *********************************************/

	/**
	* Constructor
	*/
	remote function init(){
		return this;
	}

	/**
	* Expect an exception from the testing spec
	* @type The type to expect
	* @regex Optional exception message regular expression to match, by default it matches .*
	*/
	function expectedException( type="", regex=".*" ){
		this.$expectedException = arguments;
		return this;
	}

	/**
	* Assert that the passed expression is true
	* @facade
	*/
	function assert( required expression, message="" ){
		return this.$assert.assert(argumentCollection=arguments);
	}

	/**
	* Fail an assertion
	* @facade
	*/
	function fail( message="" ){
		this.$assert.fail(argumentCollection=arguments);
	}

	/**
	* This function is used for BDD test suites to store the beforeEach() function to execute for a test suite group
	* @body The closure function
	*/
	function beforeEach( required any body ){
		this.$suitesReverseLookup[ this.$suiteContext ].beforeEach = arguments.body;
	}

	/**
	* This function is used for BDD test suites to store the afterEach() function to execute for a test suite group
	* @body The closure function
	*/
	function afterEach( required any body ){
		this.$suitesReverseLookup[ this.$suiteContext ].afterEach = arguments.body;
	}

	/**
	* This is used to surround a spec with your own closure code to provide a nice around decoration advice
	* @body The closure function
	*/
	function aroundEach( required any body ){
		this.$suitesReverseLookup[ this.$suiteContext ].aroundEach = arguments.body;
	}

	/**
	* The way to describe BDD test suites in TestBox. The title is usually what you are testing or grouping of tests.
	* The body is the function that implements the suite.
	* @title The name of this test suite
	* @body The closure that represents the test suite
	* @labels The list or array of labels this suite group belongs to
	* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
	* @skip A flag or a closure that tells TestBox to skip this suite group from testing if true. If this is a closure it must return boolean.
	*/
	any function describe(
		required string title,
		required any body,
		any labels=[],
		boolean asyncAll=false,
		any skip=false
	){

		// closure checks
		if( !isClosure( arguments.body ) && !isCustomFunction( arguments.body ) ){
			throw( type="TestBox.InvalidBody", message="The body of this test suite must be a closure and you did not give me one, what's up with that!" );
		}

		var suite = {
			// suite name
			name 		= arguments.title,
			// async flag
			asyncAll 	= arguments.asyncAll,
			// skip suite testing
			skip 		= arguments.skip,
			// labels attached to the suite for execution
			labels 		= ( isSimpleValue( arguments.labels ) ? listToArray( arguments.labels ) : arguments.labels ),
			// the test specs for this suite
			specs 		= [],
			// the recursive suites
			suites 		= [],
			// the beforeEach closure
			beforeEach 	= variables.closureStub,
			// the afterEach closure
			afterEach 	= variables.closureStub,
			// the aroundEach closure, init to empty to distinguish
			aroundEach	= "",
			// the parent suite
			parent 		= "",
			// the parent ref
			parentRef	= "",
			// hiearachy slug
			slug 		= ""
		};

		// skip constraint for suite as a closure
		if( isClosure( arguments.skip ) || isCustomFunction( arguments.skip ) ){
			suite.skip = arguments.skip( title=arguments.title,
										 body=arguments.body,
										 labels=arguments.labels,
										 asyncAll=arguments.asyncAll,
										 suite=suite );
		}

		// Are we in a nested describe() block
		if( len( this.$suiteContext ) and this.$suiteContext neq arguments.title ){
			// Append this suite to the nested suite.
			arrayAppend( this.$suitesReverseLookup[ this.$suiteContext ].suites, suite );
			this.$suitesReverseLookup[ arguments.title ] = suite;

			// Setup parent reference
			suite.parent 	= this.$suiteContext;
			suite.parentRef = this.$suitesReverseLookup[ this.$suiteContext ];

			// Build hiearachy slug separated by /
			suite.slug = this.$suitesReverseLookup[ this.$suiteContext ].slug & "/" & this.$suiteContext;
			if( left( suite.slug, 1) != "/" ){ suite.slug = "/" & suite.slug; }

			// Store parent context
			var parentContext 	= this.$suiteContext;
			var parentSpecIndex = this.$specOrderIndex;
			// Switch contexts and go deep
			this.$suiteContext 		= arguments.title;
			this.$specOrderIndex 	= 1;
			// execute the test suite definition with this context now.
			arguments.body();
			// switch back the context to parent
			this.$suiteContext 		= parentContext;
			this.$specOrderIndex 	= parentSpecIndex;
		}
		else{
			// Append this spec definition to the master root
			arrayAppend( this.$suites, suite );
			// setup pivot context now and reverse lookups
			this.$suiteContext 		= arguments.title;
			this.$specOrderIndex 	= 1;
			this.$suitesReverseLookup[ arguments.title ] = suite;
			// execute the test suite definition with this context now.
			arguments.body();
			// reset context, finalized it already.
			this.$suiteContext = "";
		}

		// Restart spec index
		this.$specOrderIndex 	= 1;

		return this;
	}

	/**
	* The way to describe BDD test suites in TestBox. The feature is an alias for describe usually use when you are writing in a Given-When-Then style
	* The body is the function that implements the suite.
	* @feature The name of this test suite
	* @body The closure that represents the test suite
	* @labels The list or array of labels this suite group belongs to
	* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
	* @skip A flag or a closure that tells TestBox to skip this suite group from testing if true. If this is a closure it must return boolean.
	*/
	any function feature(
		required string feature,
		required any body,
		any labels=[],
		boolean asyncAll=false,
		any skip=false
	){
		return describe(argumentCollection=arguments, title="Feature: " & arguments.feature);
	}

	/**
	* The way to describe BDD test suites in TestBox. The given is an alias for describe usually use when you are writing in a Given-When-Then style
	* The body is the function that implements the suite.
	* @feature The name of this test suite
	* @body The closure that represents the test suite
	* @labels The list or array of labels this suite group belongs to
	* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
	* @skip A flag or a closure that tells TestBox to skip this suite group from testing if true. If this is a closure it must return boolean.
	*/
	any function given(
		required string given,
		required any body,
		any labels=[],
		boolean asyncAll=false,
		any skip=false
	){
		return describe(argumentCollection=arguments, title="Given " & arguments.given);
	}

	/**
	* The way to describe BDD test suites in TestBox. The scenario is an alias for describe usually use when you are writing in a Given-When-Then style
	* The body is the function that implements the suite.
	* @feature The name of this test suite
	* @body The closure that represents the test suite
	* @labels The list or array of labels this suite group belongs to
	* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
	* @skip A flag or a closure that tells TestBox to skip this suite group from testing if true. If this is a closure it must return boolean.
	*/
	any function scenario(
		required string scenario,
		required any body,
		any labels=[],
		boolean asyncAll=false,
		any skip=false
	){
		return describe(argumentCollection=arguments, title="Scenario: " & arguments.scenario);
	}

	/**
	* The way to describe BDD test suites in TestBox. The when is an alias for scenario usually use when you are writing in a Given-When-Then style
	* The body is the function that implements the suite.
	* @feature The name of this test suite
	* @body The closure that represents the test suite
	* @labels The list or array of labels this suite group belongs to
	* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
	* @skip A flag or a closure that tells TestBox to skip this suite group from testing if true. If this is a closure it must return boolean.
	*/
	any function when(
		required string when,
		required any body,
		any labels=[],
		boolean asyncAll=false,
		any skip=false
	){
		return describe(argumentCollection=arguments, title="When " & arguments.when);
	}

	/**
	* The it() function describes a spec or a test in TestBox.  The body argument is the closure that implements
	* the test which usually contains one or more expectations that test the state of the code under test.
	* @title The title of this spec
	* @body The closure that represents the test
	* @labels The list or array of labels this spec belongs to
	* @skip A flag or a closure that tells TestBox to skip this spec test from testing if true. If this is a closure it must return boolean.
	*/
	any function it(
		required string title,
		required any body,
		any labels=[],
		any skip=false
	){
		// closure checks
		if( !isClosure( arguments.body ) && !isCustomFunction( arguments.body ) ){
			throw( type="TestBox.InvalidBody", message="The body of this test suite must be a closure and you did not give me one, what's up with that!" );
		}

		// Context checks
		if( !len( this.$suiteContext ) ){
			throw( type="TestBox.InvalidContext", message="You cannot define a spec without a test suite! This it() must exist within a describe() body! Go fix it :)" );
		}

		// define the spec
		var spec = {
			// spec title
			name 		= arguments.title,
			// skip spec testing
			skip 		= arguments.skip,
			// labels attached to the spec for execution
			labels 		= ( isSimpleValue( arguments.labels ) ? listToArray( arguments.labels ) : arguments.labels ),
			// the spec body
			body 		= arguments.body,
			// The order of execution
			order 		= this.$specOrderIndex++
		};

		// skip constraint for suite as a closure
		if( isClosure( arguments.skip ) || isCustomFunction( arguments.skip ) ){
			spec.skip = arguments.skip( title=arguments.title,
										body=arguments.body,
										labels=arguments.labels,
										spec=spec );
		}

		// Attach this spec to the incoming context array of specs
		arrayAppend( this.$suitesReverseLookup[ this.$suiteContext ].specs, spec );

		return this;
	}



	/**
	* The then() function describes a spec or a test in TestBox and is an alias for it.  The body argument is the closure that implements
	* the test which usually contains one or more expectations that test the state of the code under test.
	* @then The title of this spec
	* @body The closure that represents the test
	* @labels The list or array of labels this spec belongs to
	* @skip A flag or a closure that tells TestBox to skip this spec test from testing if true. If this is a closure it must return boolean.
	*/
	any function then(
		required string then,
		required any body,
		any labels=[],
		any skip=false
	){
		return it(argumentCollection=arguments, title="Then " & arguments.then);
	}

	/**
	* This is a convenience method that makes sure the test suite is skipped from execution
	* @title The name of this test suite
	* @body The closure that represents the test suite
	* @labels The list or array of labels this suite group belongs to
	* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
	*/
	any function xdescribe(
		required string title,
		required any body,
		any labels=[],
		boolean asyncAll=false
	){
		arguments.skip = true;
		return describe( argumentCollection=arguments );
	}

	/**
	* This is a convenience method that makes sure the test spec is skipped from execution
	* @title The title of this spec
	* @body The closure that represents the test
	* @labels The list or array of labels this spec belongs to
	*/
	any function xit(
		required string title,
		required any body,
		any labels=[]
	){
		arguments.skip = true;
		return it( argumentCollection=arguments );
	}

	/**
	* Start an expectation expression. This returns an instance of Expectation so you can work with its matchers.
	* @actual The actual value, it is not required as it can be null.
	*/
	Expectation function expect( any actual ){
		// build an expectation
		var oExpectation = new Expectation( spec=this, assertions=this.$assert, mockbox=this.$mockbox );

		// Store the actual data
		if( !isNull( arguments.actual ) ){
			oExpectation.actual = arguments.actual;
		} else {
			oExpectation.actual = javacast( "null", "" );
		}

		// Do we have any custom matchers to add to this expectation?
		if( !structIsEmpty( this.$customMatchers ) ){
			for( var thisMatcher in this.$customMatchers ){
				oExpectation.registerMatcher( thisMatcher, this.$customMatchers[ thisMatcher ] );
			}
		}

		return oExpectation;
	}

	/**
	* Add custom matchers to your expectations
	* @matchers The structure of custom matcher functions to register or a path or instance of a CFC containing all the matcher functions to register
	*/
	function addMatchers( required any matchers ){
		// register structure
		if( isStruct( arguments.matchers ) ){
			// register the custom matchers with override
			structAppend( this.$customMatchers, arguments.matchers, true );
			return this;
		}

		// Build the Matcher CFC
		var oMatchers = "";
		if( isSimpleValue( arguments.matchers ) ){
			oMatchers = new "#arguments.matchers#"();
		}
		else if( isObject( arguments.matchers ) ){
			oMatchers = arguments.matchers;
		}
		else{
			throw(type="TestBox.InvalidCustomMatchers", message="The matchers argument you sent is not valid, it must be a struct, string or object");
		}

		// Register the methods into our custom matchers struct
		var matcherArray = structKeyArray( oMatchers );
		for( var thisMatcher in matcherArray ){
			this.$customMatchers[ thisMatcher ] = oMatchers[ thisMatcher ];
		}

		return this;
	}

	/**
	* Add custom assertions to the $assert object
	* @assertions The structure of custom assertion functions to register or a path or instance of a CFC containing all the assertion functions to register
	*/
	function addAssertions( required any assertions ){
		// register structure
		if( isStruct( arguments.assertions ) ){
			// register the custom matchers with override
			structAppend( this.$assert, arguments.assertions, true );
			return this;
		}

		// Build the Custom Assertion CFC
		var oAssertions = "";
		if( isSimpleValue( arguments.assertions ) ){
			oAssertions = new "#arguments.assertions#"();
		}
		else if( isObject( arguments.assertions ) ){
			oAssertions = arguments.assertions;
		}
		else{
			throw(type="TestBox.InvalidCustomAssertions", message="The assertions argument you sent is not valid, it must be a struct, string or object");
		}

		// Register the methods into our custom assertions struct
		var methodArray = structKeyArray( oAssertions );
		for( var thisMethod in methodArray ){
			this.$assert[ thisMethod ] = oAssertions[ thisMethod ];
		}

		return this;
	}

	/************************************** RUN BDD METHODS *********************************************/

	/**
	* Run a test remotely, only useful if the spec inherits from this class. Useful for remote executions.
	* @testSuites A list or array of suite names that are the ones that will be executed ONLY!
	* @testSpecs A list or array of test names that are the ones that will be executed ONLY!
	* @reporter The type of reporter to run the test with
	* @labels A list or array of labels to apply to the testing.
	*/
	remote function runRemote(
		string testSpecs="",
		string testSuites="",
		string reporter="simple",
		string labels=""
	) output=true{
		var runner = new testbox.system.TestBox( bundles="#getMetadata(this).name#",
														 labels=arguments.labels,
														 reporter=arguments.reporter );

		// Produce report
		writeOutput( runner.run( testSuites=arguments.testSuites, testSpecs=arguments.testSpecs ) );
	}

	/**
	* Run a BDD test in this target CFC
	* @spec The spec definition to test
	* @suite The suite definition this spec belongs to
	* @testResults The testing results object
	* @suiteStats The suite stats that the incoming spec definition belongs to
	* @runner The runner calling this BDD test
	*/
	function runSpec(
		required spec,
		required suite,
		required testResults,
		required suiteStats,
		required runner
	){

		try{

			// init spec tests
			var specStats = arguments.testResults.startSpecStats( arguments.spec.name, arguments.suiteStats );
			// init consolidated spec labels
			var consolidatedLabels = [];
			// Build labels from nested suites, so suites inherit from parent suite labels
			var parentSuite = arguments.suite;
			while( !isSimpleValue( parentSuite ) ){
				consolidatedLabels.addAll( parentSuite.labels );
				parentSuite = parentSuite.parentref;
			}

			// Verify we can execute
			if( !arguments.spec.skip &&
				arguments.runner.canRunLabel( consolidatedLabels, arguments.testResults ) &&
				arguments.runner.canRunSpec( arguments.spec.name, arguments.testResults )
			){
				// setup the current executing spec for debug purposes
				this.$currentExecutingSpec = arguments.suite.slug & "/" & arguments.suite.name & "/" & arguments.spec.name;
				// Run beforeEach closures
				runBeforeEachClosures( arguments.suite, arguments.spec );

				try{
					// around each test
					if( isClosure( suite.aroundEach ) || isCustomFunction( suite.aroundEach ) ){
						runAroundEachClosures( arguments.suite, arguments.spec );
						//suite.aroundEach( spec=arguments.spec );
					} else {
						// Execute the Spec body
						arguments.spec.body();
					}
				} catch( any e ){
					rethrow;
				} finally {
					runAfterEachClosures( arguments.suite, arguments.spec );
				}

				// store spec status
				specStats.status 	= "Passed";
				// Increment recursive pass stats
				arguments.testResults.incrementSpecStat( type="pass", stats=specStats );
			}
			else{
				// store spec status
				specStats.status = "Skipped";
				// Increment recursive pass stats
				arguments.testResults.incrementSpecStat( type="skipped", stats=specStats );
			}
		}
		// Catch assertion failures
		catch( "TestBox.AssertionFailed" e ){
			// store spec status and debug data
			specStats.status 		= "Failed";
			specStats.failMessage 	= e.message;
			specStats.failOrigin 	= e.tagContext;
			// Increment recursive pass stats
			arguments.testResults.incrementSpecStat( type="fail", stats=specStats );
		}
		// Catch errors
		catch( any e ){
			// store spec status and debug data
			specStats.status 		= "Error";
			specStats.error 		= e;
			// Increment recursive pass stats
			arguments.testResults.incrementSpecStat( type="error", stats=specStats );
		}
		finally{
			// Complete spec testing
			arguments.testResults.endStats( specStats );
		}

		return this;
	}

	/**
	* Execute the before each closures in order for a suite and spec
	*/
	BaseSpec function runBeforeEachClosures( required suite, required spec ){
		var reverseTree = [];

		// do we have nested suites? If so, traverse the tree to build reverse execution map
		var parentSuite = arguments.suite.parentRef;
		while( !isSimpleValue( parentSuite ) ){
			arrayAppend( reverseTree, parentSuite.beforeEach );
			parentSuite = parentSuite.parentRef;
		}

		// Execute reverse tree
		var treeLen = arrayLen( reverseTree );
		if( treeLen gt 0 ){
			for( var x=treeLen; x gte 1; x-- ){
				var thisBeforeClosure = reverseTree[ x ];
				thisBeforeClosure( currentSpec=arguments.spec.name );
			}
		}

		// execute beforeEach()
		arguments.suite.beforeEach( currentSpec=arguments.spec.name );

		return this;
	}

	/**
	* Execute the around each closures in order for a suite and spec
	*/
	BaseSpec function runAroundEachClosures( required suite, required spec ){
		// TODO: Add multi-tree traversal aroundEach(), 1 level as of now.
		// execute aroundEach()
		arguments.suite.aroundEach( spec=arguments.spec, suite=arguments.suite );
		return this;
	}

	/**
	* Execute the after each closures in order for a suite and spec
	*/
	BaseSpec function runAfterEachClosures( required suite, required spec ){
		// execute nearest afterEach()
		arguments.suite.afterEach( currentSpec=arguments.spec.name );

		// do we have nested suites? If so, traverse and execute life-cycle methods up the tree backwards
		var parentSuite = arguments.suite.parentRef;
		while( !isSimpleValue( parentSuite ) ){
			parentSuite.afterEach( currentSpec=arguments.spec.name );
			parentSuite = parentSuite.parentRef;
		}
		return this;
	}

	/**
	* Runs a xUnit style test method in this target CFC
	* @spec The spec definition to test
	* @testResults The testing results object
	* @suiteStats The suite stats that the incoming spec definition belongs to
	* @runner The runner calling this BDD test
	*/
	function runTestMethod(
		required spec,
		required testResults,
		required suiteStats,
		required runner
	){

		try{

			// init spec tests
			var specStats = arguments.testResults.startSpecStats( arguments.spec.name, arguments.suiteStats );

			// Verify we can execute
			if( !arguments.spec.skip &&
				arguments.runner.canRunLabel( arguments.spec.labels, arguments.testResults ) &&
				arguments.runner.canRunSpec( arguments.spec.name, arguments.testResults )
			){

				// Reset expected exceptions: Only works on synchronous testing.
				this.$expectedException = {};
				// setup the current executing spec for debug purposes
				this.$currentExecutingSpec = arguments.spec.name;

				// execute setup()
				if( structKeyExists( this, "setup" ) ){ this.setup( currentMethod=arguments.spec.name ); }

				// Execute Spec
				try{
					evaluate( "this.#arguments.spec.name#()" );

					// Where we expecting an exception and it did not throw?
					if( hasExpectedException( arguments.spec.name, arguments.runner ) ){
						$assert.fail( 'Method did not throw expected exception: [#this.$expectedException.toString()#]' );
					} // else all good.
				} catch( Any e ){
					// do we have expected exception? else rethrow it
					if( !hasExpectedException( arguments.spec.name, arguments.runner ) ){
						rethrow;
					}
					// if not the expected exception, then fail it
					if( !isExpectedException( e, arguments.spec.name, arguments.runner ) ){
						$assert.fail( 'Method did not throw expected exception: [#this.$expectedException.toString()#], actual exception [type:#e.type#][message:#e.message#]' );
					}
				} finally {
					// execute teardown()
					if( structKeyExists( this, "teardown" ) ){ this.teardown( currentMethod=arguments.spec.name ); }
				}

				// store spec status
				specStats.status 	= "Passed";
				// Increment recursive pass stats
				arguments.testResults.incrementSpecStat( type="pass", stats=specStats );
			}
			else{
				// store spec status
				specStats.status = "Skipped";
				// Increment recursive pass stats
				arguments.testResults.incrementSpecStat( type="skipped", stats=specStats );
			}
		}
		// Catch assertion failures
		catch( "TestBox.AssertionFailed" e ){
			// store spec status and debug data
			specStats.status 		= "Failed";
			specStats.failMessage 	= e.message;
			specStats.failOrigin 	= e.tagContext;
			// Increment recursive pass stats
			arguments.testResults.incrementSpecStat( type="fail", stats=specStats );
		}
		// Catch errors
		catch( any e ){
			// store spec status and debug data
			specStats.status 		= "Error";
			specStats.error 		= e;
			// Increment recursive pass stats
			arguments.testResults.incrementSpecStat( type="error", stats=specStats );
		} finally {
			// Complete spec testing
			arguments.testResults.endStats( specStats );
		}

		return this;
	}

	/************************************** UTILITY METHODS *********************************************/

	/**
	* Send some information to the console via writedump( output="console" )
	* @var The data to send
	* @top Apply a top to the dump, by default it does 9999 levels
	*/
	any function console( required var, top=9999 ){
		writedump( var=arguments.var, output="console", top=arguments.top );
		return this;
	}

	/**
	* Debug some information into the TestBox debugger array buffer
	* @var The data to debug
	* @label The label to add to the debug entry
	* @deepCopy By default we do not duplicate the incoming information, but you can :)
	* @top The top numeric number to dump on the screen in the report, defaults to 999
	*/
	any function debug(
		any var,
		string label="",
		boolean deepCopy=false,
		numeric top="999"
	){
		// null check
		if( isNull( arguments.var ) ){ arrayAppend( this.$debugBuffer, "null" ); return; }
		// lock and add
		lock name="tb-debug-#this.$testID#" type="exclusive" timeout="10"{
			// duplication control
			var newVar = ( arguments.deepCopy ? duplicate( arguments.var ) : arguments.var );
			// compute label?
			if( !len( trim( arguments.label ) ) ){ arguments.label = this.$currentExecutingSpec; }
			// add to debug output
			arrayAppend( this.$debugBuffer, {
				data=newVar,
				label=arguments.label,
				timestamp=now(),
				thread=( isNull( cfthread ) ? structNew() : cfthread ),
				top=arguments.top
			} );
		}
		return this;
	}

	/**
	*  Clear the debug array buffer
	*/
	any function clearDebugBuffer(){
		lock name="tb-debug-#this.$testID#" type="exclusive" timeout="10"{
			arrayClear( this.$debugBuffer );
		}
		return this;
	}

	/**
	*  Get the debug array buffer from scope
	*/
	array function getDebugBuffer(){
		lock name="tb-debug-#this.$testID#" type="readonly" timeout="10"{
			return this.$debugBuffer;
		}
	}

	/**
	* Write some output to the ColdFusion output buffer
	*/
	any function print(required message) output=true{
		writeOutput( arguments.message );
		return this;
	}

	/**
	* Write some output to the ColdFusion output buffer using a <br> attached
	*/
	any function println(required message) output=true{
		return print( arguments.message & "<br>" );
	}

	/************************************** MOCKING METHODS *********************************************/

	/**
	* Make a private method on a CFC public with or without a new name and returns the target object
	* @target The target object to expose the method
	* @method The private method to expose
	* @newName If passed, it will expose the method with this name, else just uses the same name
	*/
	any function makePublic( required any target, required string method, string newName="" ){

		// decorate it
		this.$utility.getMixerUtil().start( arguments.target );
		// expose it
		arguments.target.exposeMixin( arguments.method, arguments.newName );

		return arguments.target;
	}

	/**
	* Get a private property
	* @target The target to get a property from
	* @name The name of the property to retrieve
	* @scope The scope to get it from, defaults to 'variables' scope
	* @defaultValue A default value if the property does not exist
	*/
	any function getProperty( required target, required name, scope="variables", defaultValue ){
		// stupid cf10 parser
		if( structKeyExists( arguments, "defaultValue" ) ){ arguments.default = arguments.defaultValue; }
		return prepareMock( arguments.target ).$getProperty( argumentCollection=arguments );
	}

	/**
	* First line are the query columns separated by commas. Then do a consecuent rows separated by line breaks separated by | to denote columns.
	*/
	function querySim(required queryData){
		return this.$mockBox.querySim( arguments.queryData );
	}

	/**
	* Get a reference to the MockBox engine
	* @generationPath The path to generate the mocks if passed, else uses default location.
	*/
	function getMockBox( string generationPath ){
		if( structKeyExists( arguments, "generationPath" ) ){
			this.$mockBox.setGenerationPath( arguments.generationPath );
		}
		return this.$mockBox;
	}

	/**
	* Create an empty mock
	* @className The class name of the object to mock. The mock factory will instantiate it for you
	* @object The object to mock, already instantiated
	* @callLogging Add method call logging for all mocked methods. Defaults to true
	*/
	function createEmptyMock(
		string className,
		any object,
		boolean callLogging=true
	){
		return this.$mockBox.createEmptyMock( argumentCollection=arguments );
	}

	/**
	* Create a mock with or without clearing implementations, usually not clearing means you want to build object spies
	* @className The class name of the object to mock. The mock factory will instantiate it for you
	* @object The object to mock, already instantiated
	* @clearMethods If true, all methods in the target mock object will be removed. You can then mock only the methods that you want to mock. Defaults to false
	* @callLogging Add method call logging for all mocked methods. Defaults to true
	*/
	function createMock(
		string className,
		any object,
		boolean clearMethods=false
		boolean callLogging=true
	){
		return this.$mockBox.createMock( argumentCollection=arguments );
	}

	/**
	* Prepares an already instantiated object to act as a mock for spying and much more
	* @object The object to mock, already instantiated
	* @callLogging Add method call logging for all mocked methods. Defaults to true
	*/
	function prepareMock(
		any object,
		boolean callLogging=true
	){
		return this.$mockBox.prepareMock( argumentCollection=arguments );
	}

	/**
	* Create an empty stub object that you can use for mocking
	* @callLogging Add method call logging for all mocked methods. Defaults to true
	* @extends Make the stub extend from certain CFC
	* @implements Make the stub adhere to an interface
	*/
	function createStub(
		boolean callLogging=true,
		string extends="",
		string implements=""
	){
		return this.$mockBox.createStub( argumentCollection=arguments );
	}

	// Closure Stub
	function closureStub(){}

	/**
	* Check if an expected exception is defined
	*/
	boolean function hasExpectedException( required specName, required runner ){
		// do we have an expected annotation?
		var eAnnotation = arguments.runner.getMethodAnnotation( this[ arguments.specName ], this.$exceptionAnnotation, "false" );
		if( eAnnotation != false ){
			// incorporate it.
			this.$expectedException = {
				type =  ( eAnnotation == "true" ? "" : listFirst( eAnnotation, ":" ) ),
				regex = ( find( ":", eAnnotation ) ? listLast( eAnnotation, ":" ) : ".*" )
			};
		}

		return ( structIsEmpty( this.$expectedException ) ? false : true );
	}

	/**
	* Check if the incoming exception is expected or not.
	*/
	boolean function isExpectedException( required exception, required specName, required runner ){
		var results = false;

		// normalize expected exception
		if( hasExpectedException( arguments.specName, arguments.runner ) ){
			// If no type, message expectations
			if( !len( this.$expectedException.type ) && this.$expectedException.regex eq ".*" ){
				results = true;
			}
			// Type expectation then
			else if( len( this.$expectedException.type ) &&
					 arguments.exception.type eq this.$expectedException.type &&
					 arrayLen( reMatchNoCase( this.$expectedException.regex, arguments.exception.message ) )
			){
				results = true;
			}
			// Message regex then only
			else if( this.$expectedException.regex neq ".*" &&
				arrayLen( reMatchNoCase( this.$expectedException.regex, arguments.exception.message ) )
			){
				results = true;
			}
		}

		return results;
	}
}
