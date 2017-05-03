<?php

use TinyApp\App;


/**
 * @coversDefaultClass TinyApp\App
 */
class AppTest extends PHPUnit_Framework_TestCase {


    /**
     * @test
     * @covers ::run
     * @uses \TinyApp\Service\RenderingEngine\IRenderingEngine
     */
    public function test_run() {

        // mock controller without template

        $test_exception = new \Exception();

        $mock_controller = $this
            ->getMockBuilder( 'TestController' )
            ->disableAutoload()
            ->setMethods( [
                'testAction',
                'testArgumentAction',
                'testExceptionAction',
            ] )
            ->getMock();

        $mock_controller
            ->method( 'testAction' )
            ->willReturn( true );

        $mock_controller
            ->method( 'testArgumentAction' )
            ->will( $this->returnArgument( 1 ) );

        $mock_controller
            ->method( 'testExceptionAction' )
            ->willThrowException( $test_exception );

        // mock rendering engine

        $mock_rendering_engine = $this
            ->getMockBuilder( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' )
            ->setMethods( [
                'render'
            ] )
            ->getMockForAbstractClass();

        $mock_rendering_engine
            ->method( 'render' )
            ->will( $this->returnValueMap( [
                [ true, 'template', 'foo' ],
                [ false, 'template', 'bar' ],
            ] ) );

        // mock controller with template

        $mock_controller_with_templates = $this
            ->getMockBuilder( 'TestControllerWithTemplates' )
            ->disableAutoload()
            ->setMethods( [
                'testRawAction',
                'testTemplateAction',
                'defineTemplates',
            ] )
            ->getMock();

        $mock_controller_with_templates
            ->method( 'testRawAction' )
            ->willReturn( true );

        $mock_controller_with_templates
            ->method( 'testTemplateAction' )
            ->willReturn( true );

        $mock_controller_with_templates
            ->method( 'defineTemplates' )
            ->willReturn( [
                'testTemplate' => 'template',
            ] );

        // test raw result and exception

        $stub = $this->getMockForAbstractClass( '\\TinyApp\\App' );

        $stub
            ->method( 'get' )
            ->will( $this->returnValueMap( [
                [ App::CONTROLLER_PREFIX.App::CONTROLLER_MAIN, $mock_controller ],
                [ App::CONTROLLER_PREFIX.'custom', $mock_controller ],
            ] ) );

        $result_test_0 = $stub->run( App::CONTROLLER_MAIN.':test' );
        $this->assertEquals( true, $result_test_0 );
        $this->assertInternalType( 'bool', $result_test_0 );

        $result_test_1 = $stub->run( 'test' );
        $this->assertEquals( true, $result_test_1 );
        $this->assertInternalType( 'bool', $result_test_1 );

        $result_test_2 = $stub->run( 'custom:test' );
        $this->assertEquals( true, $result_test_2 );
        $this->assertInternalType( 'bool', $result_test_2 );

        $result_test_3 = $stub->run( 'testArgument', [ 'foo', 'bar', 'baz' ] );
        $this->assertEquals( 'bar', $result_test_3 );

        try {
            $stub->run( 'testException' );
            $this->fail( 'Invoking of "testException" action does not throw an exception' );
        } catch( \Exception $ex ) {
            $this->assertEquals( $test_exception, $ex );
        }

        try {
            $stub->run( 'nonexistent_action' );
            $this->fail( 'Invoking of "nonexistent_action" action does not throw an exception' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\BadMethodCallException', $ex );
            $this->assertEquals( 'Action "nonexistent_action" of controller "'.App::CONTROLLER_MAIN.'" does not exist', $ex->getMessage() );
        }

        // test template

        $stub = $this->getMockForAbstractClass( '\\TinyApp\\App' );

        $stub
            ->method( 'get' )
            ->will( $this->returnValueMap( [
                [ App::CONTROLLER_PREFIX.App::CONTROLLER_MAIN, $mock_controller_with_templates ],
                [ App::RENDERING_ENGINE_KEY, $mock_rendering_engine ],
            ] ) );

        $result_test_4 = $stub->run( 'testRaw' );
        $this->assertEquals( true, $result_test_4 );
        $this->assertInternalType( 'bool', $result_test_4 );

        $result_test_5 = $stub->run( 'testTemplate' );
        $this->assertEquals( 'foo', $result_test_5 );
    }


}
