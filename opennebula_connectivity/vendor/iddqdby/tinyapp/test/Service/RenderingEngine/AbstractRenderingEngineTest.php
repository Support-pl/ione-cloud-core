<?php


/**
 * @coversDefaultClass \TinyApp\Service\RenderingEngine\AbstractRenderingEngine
 */
class AbstractRenderingEngineTest extends \PHPUnit_Framework_TestCase {

    private $rendering_engine;
    private $data;
    private $template_path;


    public function setUp() {

        $this->rendering_engine = $this
            ->getMockBuilder( '\\TinyApp\\Service\\RenderingEngine\\AbstractRenderingEngine' )
            ->enableAutoload()
            ->setMethods( [
                'doRender'
            ] )
            ->getMockForAbstractClass();

        $this->rendering_engine
            ->method( 'doRender' )
            ->will( $this->returnCallback( function ( $data, $template_path ) {
                $this->assertSame( $this->data, $data );
                $this->assertEquals( $this->template_path, $template_path );
                return 'success';
            } ) );

        $this->data = new \stdClass();

        $this->template_path = null;
    }


    /**
     * @test
     * @covers ::addTemplateDirectories
     * @covers ::removeTemplateDirectories
     * @covers ::getTemplateDirectories
     * @covers ::render
     */
    public function test_template_dirs() {

        $templates = [
            1 => 'template1.ext',
            2 => 'template2.ext',
            3 => 'template3.ext',
            4 => 'template4.ext',
        ];

        $templates_dirs = [
            0 => TEST_DIR_ROOT.'/'.TEST_DIR_TEMPLATES.'/nonexistent',
            1 => TEST_DIR_ROOT.'/'.TEST_DIR_TEMPLATES.'/dir1',
            2 => TEST_DIR_ROOT.'/'.TEST_DIR_TEMPLATES.'/dir2',
        ];

        $this->assertEquals( [], $this->rendering_engine->getTemplateDirectories() );

        try {
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        // dir1

        $this->rendering_engine->addTemplateDirectories( $templates_dirs[1] );

        $this->assertEquals( array_values( [
            $templates_dirs[1],
        ] ), array_values( $this->rendering_engine->getTemplateDirectories() ) );

        $this->template_path = $templates_dirs[1].'/'.$templates[1];
        $result_0 = $this->rendering_engine->render( $this->data, $templates[1] );
        $this->assertEquals( 'success', $result_0 );

        $this->template_path = $templates_dirs[1].'/'.$templates[2];
        $result_1 = $this->rendering_engine->render( $this->data, $templates[2] );
        $this->assertEquals( 'success', $result_1 );

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[3];
            $this->rendering_engine->render( $this->data, $templates[3] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[3].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[4];
            $this->rendering_engine->render( $this->data, $templates[4] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[4].' not found', $ex->getMessage() );
        }

        // (remove)

        $this->rendering_engine->removeTemplateDirectories( $templates_dirs[1] );

        $this->assertEquals( [], $this->rendering_engine->getTemplateDirectories() );

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[1];
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[2];
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[3];
            $this->rendering_engine->render( $this->data, $templates[3] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[3].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[4];
            $this->rendering_engine->render( $this->data, $templates[4] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[4].' not found', $ex->getMessage() );
        }

        // dir1 + dir2

        $this->rendering_engine->addTemplateDirectories( [
            $templates_dirs[1],
            $templates_dirs[2],
        ] );

        $this->assertEquals( array_values( [
            $templates_dirs[1],
            $templates_dirs[2],
        ] ), array_values( $this->rendering_engine->getTemplateDirectories() ) );

        $this->template_path = $templates_dirs[1].'/'.$templates[1];
        $result_2 = $this->rendering_engine->render( $this->data, $templates[1] );
        $this->assertEquals( 'success', $result_2 );

        $this->template_path = $templates_dirs[1].'/'.$templates[2];
        $result_3 = $this->rendering_engine->render( $this->data, $templates[2] );
        $this->assertEquals( 'success', $result_3 );

        $this->template_path = $templates_dirs[2].'/'.$templates[3];
        $result_4 = $this->rendering_engine->render( $this->data, $templates[3] );
        $this->assertEquals( 'success', $result_4 );

        $this->template_path = $templates_dirs[2].'/'.$templates[4];
        $result_5 = $this->rendering_engine->render( $this->data, $templates[4] );
        $this->assertEquals( 'success', $result_5 );

        // (remove)

        $this->rendering_engine->removeTemplateDirectories( [
            $templates_dirs[1],
            $templates_dirs[2],
        ] );

        $this->assertEquals( [], $this->rendering_engine->getTemplateDirectories() );

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[1];
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[2];
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[3];
            $this->rendering_engine->render( $this->data, $templates[3] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[3].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[4];
            $this->rendering_engine->render( $this->data, $templates[4] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[4].' not found', $ex->getMessage() );
        }

        // dir1 + dir2 + nonexistent, duplicates

        $this->rendering_engine->addTemplateDirectories( [

            $templates_dirs[0],
            $templates_dirs[1],
            $templates_dirs[2],

            $templates_dirs[0],
            $templates_dirs[1],
            $templates_dirs[2],

        ] );

        $this->assertEquals( array_values( [
            $templates_dirs[0],
            $templates_dirs[1],
            $templates_dirs[2],
        ] ), array_values( $this->rendering_engine->getTemplateDirectories() ) );

        $this->template_path = $templates_dirs[1].'/'.$templates[1];
        $result_6 = $this->rendering_engine->render( $this->data, $templates[1] );
        $this->assertEquals( 'success', $result_6 );

        $this->template_path = $templates_dirs[1].'/'.$templates[2];
        $result_7 = $this->rendering_engine->render( $this->data, $templates[2] );
        $this->assertEquals( 'success', $result_7 );

        $this->template_path = $templates_dirs[2].'/'.$templates[3];
        $result_8 = $this->rendering_engine->render( $this->data, $templates[3] );
        $this->assertEquals( 'success', $result_8 );

        $this->template_path = $templates_dirs[2].'/'.$templates[4];
        $result_9 = $this->rendering_engine->render( $this->data, $templates[4] );
        $this->assertEquals( 'success', $result_9 );

        // (partial remove)

        $this->rendering_engine->removeTemplateDirectories( $templates_dirs[1] );

        $this->assertEquals( array_values( [
            $templates_dirs[0],
            $templates_dirs[2],
        ] ), array_values( $this->rendering_engine->getTemplateDirectories() ) );

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[1];
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[2];
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        $this->template_path = $templates_dirs[2].'/'.$templates[3];
        $result_10 = $this->rendering_engine->render( $this->data, $templates[3] );
        $this->assertEquals( 'success', $result_10 );

        $this->template_path = $templates_dirs[2].'/'.$templates[4];
        $result_11 = $this->rendering_engine->render( $this->data, $templates[4] );
        $this->assertEquals( 'success', $result_11 );

        // (partial remove)

        $this->rendering_engine->removeTemplateDirectories( $templates_dirs[0] );

        $this->assertEquals( array_values( [
            $templates_dirs[2],
        ] ), array_values( $this->rendering_engine->getTemplateDirectories() ) );

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[1];
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[2];
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        $this->template_path = $templates_dirs[2].'/'.$templates[3];
        $result_12 = $this->rendering_engine->render( $this->data, $templates[3] );
        $this->assertEquals( 'success', $result_12 );

        $this->template_path = $templates_dirs[2].'/'.$templates[4];
        $result_13 = $this->rendering_engine->render( $this->data, $templates[4] );
        $this->assertEquals( 'success', $result_13 );

        // (remove, remove removed)

        $this->rendering_engine->removeTemplateDirectories( [
            $templates_dirs[0],
            $templates_dirs[1],
            $templates_dirs[2],
        ] );

        $this->assertEquals( [], $this->rendering_engine->getTemplateDirectories() );

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[1];
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[1].'/'.$templates[2];
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[3];
            $this->rendering_engine->render( $this->data, $templates[3] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[3].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $templates_dirs[2].'/'.$templates[4];
            $this->rendering_engine->render( $this->data, $templates[4] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[4].' not found', $ex->getMessage() );
        }

    }


    /**
     * @test
     * @depends test_template_dirs
     * @covers ::setTemplatePrefix
     * @covers ::setTemplatePostfix
     * @covers ::getTemplatePrefix
     * @covers ::getTemplatePostfix
     * @covers ::render
     */
    public function test_template_names() {

        $templates = [
            1 => 'template1.ext',
            2 => 'template2.ext',
            3 => 'template1',
            4 => 'template2',
            5 => '1',
            6 => '2',
            7 => '1.ext',
            8 => '2.ext',
        ];

        $this->assertEquals( '', $this->rendering_engine->getTemplatePostfix() );
        $this->assertEquals( '', $this->rendering_engine->getTemplatePrefix() );

        $template_dir = TEST_DIR_ROOT.'/'.TEST_DIR_TEMPLATES.'/dir1';
        $this->rendering_engine->addTemplateDirectories( $template_dir );

        // '', '.ext'

        $this->rendering_engine->setTemplatePostfix( '.ext' );

        $this->assertEquals( '.ext', $this->rendering_engine->getTemplatePostfix() );
        $this->assertEquals( '', $this->rendering_engine->getTemplatePrefix() );

        try {
            $this->template_path = $template_dir.'/template1.ext';
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $template_dir.'/template2.ext';
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        $this->template_path = $template_dir.'/template1.ext';
        $result_0 = $this->rendering_engine->render( $this->data, $templates[3] );
        $this->assertEquals( 'success', $result_0 );

        $this->template_path = $template_dir.'/template2.ext';
        $result_1 = $this->rendering_engine->render( $this->data, $templates[4] );
        $this->assertEquals( 'success', $result_1 );

        // 'template', '.ext'

        $this->rendering_engine->setTemplatePrefix( 'template' );

        $this->assertEquals( '.ext', $this->rendering_engine->getTemplatePostfix() );
        $this->assertEquals( 'template', $this->rendering_engine->getTemplatePrefix() );

        try {
            $this->template_path = $template_dir.'/template1.ext';
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $template_dir.'/template2.ext';
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        $this->template_path = $template_dir.'/template1.ext';
        $result_2 = $this->rendering_engine->render( $this->data, $templates[5] );
        $this->assertEquals( 'success', $result_2 );

        $this->template_path = $template_dir.'/template2.ext';
        $result_3 = $this->rendering_engine->render( $this->data, $templates[6] );
        $this->assertEquals( 'success', $result_3 );

        // 'template', ''

        $this->rendering_engine->setTemplatePostfix( '' );

        $this->assertEquals( '', $this->rendering_engine->getTemplatePostfix() );
        $this->assertEquals( 'template', $this->rendering_engine->getTemplatePrefix() );

        try {
            $this->template_path = $template_dir.'/template1.ext';
            $this->rendering_engine->render( $this->data, $templates[1] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[1].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $template_dir.'/template2.ext';
            $this->rendering_engine->render( $this->data, $templates[2] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[2].' not found', $ex->getMessage() );
        }

        $this->template_path = $template_dir.'/template1.ext';
        $result_4 = $this->rendering_engine->render( $this->data, $templates[7] );
        $this->assertEquals( 'success', $result_4 );

        $this->template_path = $template_dir.'/template2.ext';
        $result_5 = $this->rendering_engine->render( $this->data, $templates[8] );
        $this->assertEquals( 'success', $result_5 );

        // '', ''

        $this->rendering_engine->setTemplatePrefix( '' );

        $this->assertEquals( '', $this->rendering_engine->getTemplatePostfix() );
        $this->assertEquals( '', $this->rendering_engine->getTemplatePrefix() );

        $this->template_path = $template_dir.'/template1.ext';
        $result_6 = $this->rendering_engine->render( $this->data, $templates[1] );
        $this->assertEquals( 'success', $result_6 );

        $this->template_path = $template_dir.'/template2.ext';
        $result_7 = $this->rendering_engine->render( $this->data, $templates[2] );
        $this->assertEquals( 'success', $result_7 );

        try {
            $this->template_path = $template_dir.'/template1.ext';
            $this->rendering_engine->render( $this->data, $templates[3] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[3].' not found', $ex->getMessage() );
        }

        try {
            $this->template_path = $template_dir.'/template2.ext';
            $this->rendering_engine->render( $this->data, $templates[4] );
            $this->fail( 'Expected exception not thrown' );
        } catch( \Exception $ex ) {
            $this->assertInstanceOf( '\\TinyApp\\Exception\\TemplateNotFoundException', $ex );
            $this->assertEquals( 'Template '.$templates[4].' not found', $ex->getMessage() );
        }

    }


}
