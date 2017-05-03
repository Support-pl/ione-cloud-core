<?php

use TinyApp\Service\RenderingEngine\MergedRenderingEngine;
use TinyApp\Exception\TemplateException;


/**
 * @coversDefaultClass \TinyApp\Service\RenderingEngine\MergedRenderingEngine
 */
class MergedRenderingEngineTest extends \PHPUnit_Framework_TestCase {


    /**
     * @test
     * @covers ::__construct
     * @expectedException \RuntimeException
     * @expectedExceptionMessage Array of rendering engines is empty
     */
    public function test_construct_exception_empty() {
        new MergedRenderingEngine( [] );
    }


    /**
     * @test
     * @covers ::__construct
     * @dataProvider engines_illegal
     * @expectedException \RuntimeException
     * @expectedExceptionMessageRegExp /Value at index ".+" is not an instance of IRenderingEngine/
     */
    public function test_construct_exception_illegal_class( array $engines ) {
        new MergedRenderingEngine( $engines );
    }


    /**
     * @test
     * @covers ::setTemplatePrefix
     * @covers ::getTemplatePrefix
     * @covers ::setTemplatePostfix
     * @covers ::getTemplatePostfix
     * @covers ::addTemplateDirectories
     * @covers ::removeTemplateDirectories
     * @covers ::getTemplateDirectories
     */
    public function test_prefix_postfix_dirs() {

        $engine_0 = $this
            ->getMockBuilder( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' )
            ->setMethods( [
                'setTemplatePrefix',
                'getTemplatePrefix',
                'setTemplatePostfix',
                'getTemplatePostfix',
                'addTemplateDirectories',
                'removeTemplateDirectories',
                'getTemplateDirectories',
            ] )
            ->getMockForAbstractClass();

        $engine_1 = clone $engine_0;

        // ::setTemplatePrefix

        $engine_0
            ->expects( $this->once() )
            ->method( 'setTemplatePrefix' )
            ->with( $this->equalTo( 'foo' ) );

        $engine_1
            ->expects( $this->once() )
            ->method( 'setTemplatePrefix' )
            ->with( $this->equalTo( 'foo' ) );

        // ::getTemplatePrefix

        $engine_0
            ->expects( $this->once() )
            ->method( 'getTemplatePrefix' )
            ->willReturn( 'bar' );

        $engine_1
            ->expects( $this->never() )
            ->method( 'getTemplatePrefix' );

        // ::setTemplatePostfix

        $engine_0
            ->expects( $this->once() )
            ->method( 'setTemplatePostfix' )
            ->with( $this->equalTo( 'baz' ) );

        $engine_1
            ->expects( $this->once() )
            ->method( 'setTemplatePostfix' )
            ->with( $this->equalTo( 'baz' ) );

        // ::getTemplatePostfix

        $engine_0
            ->expects( $this->once() )
            ->method( 'getTemplatePostfix' )
            ->willReturn( 'qux' );

        $engine_1
            ->expects( $this->never() )
            ->method( 'getTemplatePostfix' );

        // ::addTemplateDirectories

        $dirs_0 = [ 'a', 'b' ];

        $engine_0
            ->expects( $this->once() )
            ->method( 'addTemplateDirectories' )
            ->with( $this->equalTo( $dirs_0 ) );

        $engine_1
            ->expects( $this->once() )
            ->method( 'addTemplateDirectories' )
            ->with( $this->equalTo( $dirs_0 ) );

        // ::removeTemplateDirectories

        $dirs_1 = [ 'c', 'd' ];

        $engine_0
            ->expects( $this->once() )
            ->method( 'removeTemplateDirectories' )
            ->with( $this->equalTo( $dirs_1 ) );

        $engine_1
            ->expects( $this->once() )
            ->method( 'removeTemplateDirectories' )
            ->with( $this->equalTo( $dirs_1 ) );

        // ::getTemplateDirectories

        $engine_0
            ->expects( $this->once() )
            ->method( 'getTemplateDirectories' )
            ->willReturn( [ 'e', 'f' ] );

        $engine_1
            ->expects( $this->once() )
            ->method( 'getTemplateDirectories' )
            ->willReturn( [ 'f', 'g' ] );

        // test

        $engine_merged = new MergedRenderingEngine( [ $engine_0, $engine_1 ] );

        $engine_merged->setTemplatePrefix( 'foo' );

        $result_0 = $engine_merged->getTemplatePrefix();
        $this->assertEquals( 'bar', $result_0 );

        $engine_merged->setTemplatePostfix( 'baz' );

        $result_1 = $engine_merged->getTemplatePostfix();
        $this->assertEquals( 'qux', $result_1 );

        $engine_merged->addTemplateDirectories( $dirs_0 );

        $engine_merged->removeTemplateDirectories( $dirs_1 );

        $result_2 = $engine_merged->getTemplateDirectories();
        $this->assertCount( 3, $result_2 );
        $this->assertContains( 'e', $result_2 );
        $this->assertContains( 'f', $result_2 );
        $this->assertContains( 'g', $result_2 );
    }


    /**
     * @test
     * @covers ::render
     */
    public function test_render_success() {

        $engine_0 = $this
            ->getMockBuilder( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' )
            ->setMethods( [
                'render',
            ] )
            ->getMockForAbstractClass();

        $engine_1 = clone $engine_0;

        $data = [ 'foo', 'bar' ];
        $template = 'a';

        $engine_0
            ->expects( $this->once() )
            ->method( 'render' )
            ->with( $this->equalTo( $data ), $this->equalTo( $template ) )
            ->willReturn( 'baz' );

        $engine_1
            ->expects( $this->never() )
            ->method( 'render' );

        // test

        $engine_merged = new MergedRenderingEngine( [ $engine_0, $engine_1 ] );

        $result = $engine_merged->render( $data, $template );
        $this->assertEquals( 'baz', $result );
    }


    /**
     * @test
     * @covers ::render
     */
    public function test_render_exception_success() {

        $engine_0 = $this
            ->getMockBuilder( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' )
            ->setMethods( [
                'render',
            ] )
            ->getMockForAbstractClass();

        $engine_1 = clone $engine_0;
        $engine_2 = clone $engine_0;

        $callback = $this
            ->getMockBuilder( 'Callback' )
            ->disableAutoload()
            ->setMethods( [
                'invoke'
            ] )
            ->getMock();

        $data = [ 'foo', 'bar' ];
        $template = 'a';

        $engine_0
            ->expects( $this->once() )
            ->method( 'render' )
            ->with( $this->equalTo( $data ), $this->equalTo( $template ) )
            ->willThrowException( new TemplateException( 'baz' ) );

        $engine_1
            ->expects( $this->once() )
            ->method( 'render' )
            ->with( $this->equalTo( $data ), $this->equalTo( $template ) )
            ->willThrowException( new TemplateException( 'qux' ) );

        $engine_2
            ->expects( $this->once() )
            ->method( 'render' )
            ->with( $this->equalTo( $data ), $this->equalTo( $template ) )
            ->willReturn( 'baz' );

        $callback
            ->expects( $this->exactly( 2 ) )
            ->method( 'invoke' )
            ->with(
                $this->isInstanceOf( '\\TinyApp\\Exception\\TemplateException' ),
                $this->equalTo( $template ),
                $this->equalTo( $data ),
                $this->isInstanceOf( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' )
            )
            ->willReturnCallback( function (
                    TemplateException $ex,
                    $template_passed,
                    $data_passed,
                    $engine_passed
            ) use ( &$data, &$template, &$engine_0, &$engine_1 ) {

                $this->assertEquals( $template, $template_passed );
                $this->assertEquals( $data, $data_passed );

                $message = $ex->getMessage();

                switch( $message ) {
                    case 'baz':
                        $this->assertSame( $engine_0, $engine_passed );
                        break;
                    case 'qux':
                        $this->assertSame( $engine_1, $engine_passed );
                        break;
                    default:
                        $this->fail( 'Wrong exception message' );
                }

            } );

        // test

        $engine_merged = new MergedRenderingEngine(
            [ $engine_0, $engine_1, $engine_2 ],
            [ $callback, 'invoke' ]
        );

        $result = $engine_merged->render( $data, $template );
        $this->assertEquals( 'baz', $result );
    }


    /**
     * @test
     * @covers ::render
     * @expectedException \TinyApp\Exception\TemplateException
     * @expectedExceptionMessage qux
     */
    public function test_render_exception_fail() {

        $engine_0 = $this
            ->getMockBuilder( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' )
            ->setMethods( [
                'render',
            ] )
            ->getMockForAbstractClass();

        $engine_1 = clone $engine_0;

        $data = [ 'foo', 'bar' ];
        $template = 'a';

        $engine_0
            ->expects( $this->once() )
            ->method( 'render' )
            ->with( $this->equalTo( $data ), $this->equalTo( $template ) )
            ->willThrowException( new TemplateException( 'baz' ) );

        $engine_1
            ->expects( $this->once() )
            ->method( 'render' )
            ->with( $this->equalTo( $data ), $this->equalTo( $template ) )
            ->willThrowException( new TemplateException( 'qux' ) );

        // test

        $engine_merged = new MergedRenderingEngine( [ $engine_0, $engine_1 ] );
        $engine_merged->render( $data, $template );
    }


    public function engines_illegal() {
        return [
            [ [ new stdClass() ] ],
            [ [ new stdClass(), $this->getMockForAbstractClass( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' ) ] ],
            [ [ $this->getMockForAbstractClass( '\\TinyApp\\Service\\RenderingEngine\\IRenderingEngine' ), new stdClass() ] ],
        ];
    }

}
