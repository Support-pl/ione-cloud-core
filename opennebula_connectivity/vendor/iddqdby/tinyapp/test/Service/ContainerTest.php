<?php

use TinyApp\Service\Container;


/**
 * @coversDefaultClass TinyApp\Service\Container
 */
class ContainerTest extends \PHPUnit_Framework_TestCase {

    private $container;


    protected function setUp() {
        $this->container = new Container();
    }


    /**
     * @test
     */
    public function test_values() {

        $result_0 = $this->container['foo'] = 'bar';
        $this->assertEquals( 'bar', $result_0 );

        $result_1 = $this->container['foo'];
        $this->assertEquals( 'bar', $result_1 );

        try {
            strval( $this->container['baz'] );
            $this->fail( 'Method "offsetGet" doesn\'t throw exception for undefined key' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\OutOfBoundsException', $ex );
            $this->assertEquals( 'Key "baz" is not defined', $ex->getMessage() );
        }

        try {
            $this->container['foo'] = 'qux';
            $this->fail( 'Method "offsetSet" doesn\'t throw exception for already defined key' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\BadMethodCallException', $ex );
            $this->assertEquals( 'Key "foo" has already been set', $ex->getMessage() );
        }

        $this->assertTrue( isset( $this->container['foo'] ) );
        $this->assertFalse( isset( $this->container['baz'] ) );
        $this->assertFalse( isset( $this->container['corge'] ) );

        try {
            unset( $this->container['foo'] );
            $this->fail( 'Method "offsetUnset" doesn\'t throw exception for already defined key' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\BadMethodCallException', $ex );
            $this->assertEquals( 'Key "foo" has already been set', $ex->getMessage() );
        }

        unset( $this->container['baz'] );
        unset( $this->container['corge'] );

        $this->assertTrue( isset( $this->container['foo'] ) );
        $this->assertFalse( isset( $this->container['baz'] ) );
        $this->assertFalse( isset( $this->container['corge'] ) );

    }


    /**
     * @test
     */
    public function test_callbacks() {

        $callback_0 = function () {
            return 'bar';
        };

        $result_0 = $this->container['foo'] = $callback_0;
        $this->assertEquals( $callback_0, $result_0 );

        $result_1 =  $this->container['foo'];
        $this->assertEquals( 'bar', $result_1 );

        $this->container['baz'] = function ( $c ) {
            $this->assertSame( $this->container, $c );
            return 'qux';
        };

        $result_2 = $this->container['baz'];
        $this->assertEquals( 'qux', $result_2 );

        $this->container['corge'] = function () {
            static $i = 1;
            return $i++;
        };

        $result_3 = $this->container['corge'];
        $result_4 = $this->container['corge'];

        $this->assertEquals( 1, $result_3 );
        $this->assertInternalType( 'int', $result_3 );
        $this->assertEquals( 1, $result_4, 'Definition callback must be called only once' );
        $this->assertInternalType( 'int', $result_4, 'Definition callback must be called only once' );

        $this->container['grault'] = function () {
            return null;
        };

        $result_5 = $this->container['grault'];
        $this->assertNull( $result_5 );
        $this->assertTrue( isset( $this->container['grault'] ) );

        $this->container['garply'] = function () {
            return true;
        };

        $this->assertTrue( isset( $this->container['foo'] ) );
        $this->assertTrue( isset( $this->container['baz'] ) );
        $this->assertTrue( isset( $this->container['baz'] ) );
        $this->assertTrue( isset( $this->container['corge'] ) );
        $this->assertTrue( isset( $this->container['grault'] ) );
        $this->assertTrue( isset( $this->container['garply'] ) );
        $this->assertFalse( isset( $this->container['waldo'] ) );

        try {
            unset( $this->container['foo'] );
            $this->fail( 'Method "offsetUnset" doesn\'t throw exception for already defined key' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\BadMethodCallException', $ex );
            $this->assertEquals( 'Key "foo" has already been set', $ex->getMessage() );
        }

        try {
            unset( $this->container['corge'] );
            $this->fail( 'Method "offsetUnset" doesn\'t throw exception for already defined key' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\BadMethodCallException', $ex );
            $this->assertEquals( 'Key "corge" has already been set', $ex->getMessage() );
        }

        unset( $this->container['garply'] );
        unset( $this->container['waldo'] );

        $this->assertTrue( isset( $this->container['foo'] ) );
        $this->assertTrue( isset( $this->container['baz'] ) );
        $this->assertTrue( isset( $this->container['baz'] ) );
        $this->assertTrue( isset( $this->container['corge'] ) );
        $this->assertTrue( isset( $this->container['grault'] ) );
        $this->assertFalse( isset( $this->container['garply'] ) );
        $this->assertFalse( isset( $this->container['waldo'] ) );
    }


    /**
     * @test
     * @expectedException \LogicException
     * @expectedExceptionMessage Recursion in dependencies detected: key "baz"
     */
    public function test_recursion() {

        $this->container['foo'] = function () {
            return 'foo';
        };

        $this->container['bar'] = function () {
            return 'bar';
        };

        $this->container['baz'] = function ( $c ) {
            return $c['foo'].$c['bar'].$c['qux'];
        };

        $this->container['qux'] = function ( $c ) {
            return $c['foo'].$c['bar'].$c['baz'];
        };

        strval( $this->container['baz'] );

    }


}
