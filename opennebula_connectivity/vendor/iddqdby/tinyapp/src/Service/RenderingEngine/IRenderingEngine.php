<?php

/*
 * The MIT License
 *
 * Copyright 2016 Sergey Protasevich.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

namespace TinyApp\Service\RenderingEngine;

use TinyApp\Exception\TemplateException;


/**
 * Interface of a rendering engine.
 */
interface IRenderingEngine {


    /**
     * Render given template using given data.
     *
     * @param mixed $data the data
     * @param mixed $template the template
     * @return string rendered template as a string
     * @throws TemplateException in case of an error
     */
    public function render( $data, $template );


    /**
     * Set prefix of template filenames.
     *
     * @param string $prefix the prefix
     * @return IRenderingEngine this
     */
    public function setTemplatePrefix( $prefix );


    /**
     * Get prefix of template filenames.
     *
     * @return string prefix of template filenames
     */
    public function getTemplatePrefix();


    /**
     * Set postfix of template filenames.
     *
     * May be used to set extension of templates, like ".twig" or ".tpl".
     *
     * @param string $postfix the postfix
     * @return IRenderingEngine this
     */
    public function setTemplatePostfix( $postfix );


    /**
     * Get postfix of template filenames.
     *
     * @return string postfix of template filenames
     */
    public function getTemplatePostfix();


    /**
     * Add directory or directories to search templates in.
     *
     * @param string|array $dirs path or array of pathes to directories
     * @return IRenderingEngine this
     */
    public function addTemplateDirectories( $dirs );


    /**
     * Remove directory or directories that have been added previously to search templates in.
     *
     * @param string|array $dirs path or array of pathes to directories
     * @return IRenderingEngine this
     */
    public function removeTemplateDirectories( $dirs );


    /**
     * Get array of directories to search templates in.
     *
     * @return array array of directories to search templates in
     */
    public function getTemplateDirectories();

}
