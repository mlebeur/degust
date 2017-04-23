

# TODO
# import { DataFrame } from 'lib/utils/data-frame'

# A basic scatter plot
# Should be fast with lots of points, tested with ~20,000
# Draws points to a canvas
# Brush using SVG
# Highlight functionality
# Mouseover capability
# Events to listen for brush, mouseover, mouseout
# "mouseover" is debounced to prevent calling too often with many points

# TODO: Isolate classes!
css = {axis: 'axis', scatter: 'scatter'}

class ScatterPlot
    constructor: (@opts={}) ->
        @opts.name ?= "scatter"         # Used for saving filename
        @opts.padding ?= 30
        @opts.xaxis_loc ?= 'zero'       # 'zero' or 'bottom'
        @opts.yaxis_loc ?= 'left'       # 'zero' or 'left'
        @opts.colouring ?= () -> 'blue'
        @opts.alpha ?= () -> 0.7
        @opts.size ?= () -> 3
        @opts.filter ?= () -> true
        @opts.brush_enable ?= false
        @opts.animate ?= false             # Attempt to transition dots around.  Only works for canvas

        @elem = d3.select(@opts.elem).append('div')
        @elem.attr('class', css.scatter)

        if (@opts.width)
            @elem.style("width", @opts.width+"px")
        if (@opts.height)
            @elem.style("height", @opts.height+"px")

        # Create a custom 'brush' event.  This will allow same API as par-coords
        @dispatch = d3.dispatch("brush","mouseover","mouseout")

        if (@opts.canvas)
            @init_canvas()
        else
            @init_svg()

        @gHighlight = @svg.append('g')
        @resize()
        @_make_menu(@opts.elem)

    resize: () ->
        @width = @opts.width || @elem.node().clientWidth
        @height = @opts.height || @elem.node().clientHeight
        @svg.attr("width", @width)
                .attr("height", @height)
        if (@gDot != @svg)
            @gDot.attr("width", @width)
                     .attr("height", @height)

        @redraw()


    init_canvas: () ->
        @_draw_dots = @_draw_dots_canvas
        @gDot = @elem.append('canvas')

        @svg = @elem.append('svg')
        @svg.style("pointer-events", "none")

        # Brushing enabled?  Note mouse events must be on the brush layer if there is one
        if (@opts.brush_enable)
            @gBrush = @svg.append('g')
            @gBrush.on('mousemove', () => @_mouse_move())
            @gBrush.on('mouseout',  () => @_mouse_out())
        else
            @gDot.on('mousemove', () => @_mouse_move())
            @gDot.on('mouseout',  () => @_mouse_out())

    init_svg: () ->
        @_draw_dots = @_draw_dots_svg
        @svg = @elem.append('svg')
        @gDot = @svg

        # Brushing enabled?  Note mouse events must be on the brush layer if there is one
        if (@opts.brush_enable)
            @svg.style("pointer-events", "none")
            @gBrush = @svg.append('g')
            @gBrush.on('mousemove', () => @_mouse_move())
            @gBrush.on('mouseout',  () => @_mouse_out())
        else
            @gDot.on('mousemove', () => @_mouse_move())
            @gDot.on('mouseout',  () => @_mouse_out())

    update_data: (@data, @xColumn, @yColumn, @colouring) ->
        # TODO
        # if (@data instanceof DataFrame)
        #     @data = @data.get_data()
        @redraw()

    redraw: () ->
        if (!@data)
            return

        @svg.select("g.brush").remove()
        @svg.selectAll(".#{css.axis}").remove()

        @x_val = x_val = (d) => @xColumn.get(d)
        @y_val = y_val = (d) => @yColumn.get(d)

        @xScale = xScale = d3.scale.linear()
                     .domain(d3.extent(@data, (d) => x_val(d)).map((x) => x))
                     .range([@opts.padding, @width-@opts.padding])
        @yScale = yScale = d3.scale.linear()
                     .domain(d3.extent(@data, (d) => y_val(d)).map((x) => x))
                     .range([@height-@opts.padding, @opts.padding])

        xAxis = d3.svg.axis()
                  .scale(xScale)
                  .orient("bottom")
        yAxis = d3.svg.axis()
                  .scale(yScale)
                  .orient("left")
                  .ticks(5)

        if (@opts.brush_enable)
            @mybrush = d3.svg.brush()
                         .x(xScale)
                         .y(yScale)
                         .clamp([false,false])
                         .on("brush",  () => @_brushed())
                     #   .on("end", () => @_brushed())    # Needed as "brush" isn't fired on clearing
            @gBrush.call(@mybrush)

        @_draw_dots(@colouring || @opts.colouring)

        xaxis_loc = switch (@opts.xaxis_loc)
            when 'bottom' then yScale.domain()[0]
            when 'zero'
                if (yScale.domain()[0]<0 && yScale.domain()[1]>0)
                    0
                else
                    yScale.domain()[0]
            else yScale.domain()[0]

        yaxis_loc = switch (@opts.yaxis_loc)
            when 'left' then xScale.domain()[0]
            when 'zero'
                if (xScale.domain()[0]<0 && xScale.domain()[1]>0)
                    0
                else
                    xScale.domain()[0]
            else xScale.domain()[0]

        @svg.append("g")
            .attr("class", css.axis)
            .attr("transform", "translate(0,#{yScale(xaxis_loc)})")
            .call(xAxis)
           .append("text")
            .attr("x", xScale.range()[1])
            .attr("y", -6)
            .attr("fill", "black")
            .style("text-anchor", "end")
            .text(@_chooseOne(@xColumn.name, @opts.xLabel))

        @svg.append("g")
            .attr("class", css.axis)
            .attr("transform", "translate(#{xScale(yaxis_loc)},0)")
            .call(yAxis)
           .append("text")
            .attr("transform", "rotate(-90)")
            .attr("x", -5)
            .attr("y", 5)
            .attr("fill", "black")
            .attr("dy", ".71em")
            .style("text-anchor", "end")
            .text(@_chooseOne(@yColumn.name, @opts.yLabel))


    _make_menu: (el) ->
        print_menu = (new Print((() => @_svg_for_print()), @opts.name)).menu()
        # menu = [
        #        divider: true
        #        ]
        d3.select(el).on('contextmenu', d3.contextMenu(print_menu))


    _svg_for_print: () ->
        if (!@opts.canvas)
            return @svg.node()
        holder = document.createElement('div')
        holder.setAttribute('id','scatter-print-holder')
        document.body.append(holder)
        sub = new ScatterPlot(
                elem: '#scatter-print-holder'
                filter: @opts.filter
                canvas: false
                height: 300
                width: 600
                xaxis_loc: @opts.xaxis_loc
                yaxis_loc: @opts.yaxis_loc
                )
        sub.update_data(@data, @xColumn, @yColumn, @colouring)
        svg = d3.select(sub.svg.node().cloneNode(true))
        svg.attr('class','')
        Print.copy_svg_style_deep(sub.svg, svg)
        document.body.removeChild(holder)
        {svg: svg.node(), width: @width, height: @height}

    _chooseOne: (v1,v2) ->
        if (v1 != null)
            if (typeof v1 == "function")
                return v1()
            else
                return v1

        else
            if (typeof v2 == "function")
                return v2()
            else
                return v2

    _draw_dots_canvas: (colouring) ->
        ctx = @gDot.node().getContext("2d")
        ctx.clearRect(0,0,@opts.width, @opts.height)
        i=@data.length
        while(i--)
            do (i) =>
                d = @data[i]
                if (@opts.filter(d))
                    ctx.fillStyle   = colouring(d)
                    ctx.globalAlpha = @opts.alpha(d)
                    [x,y] = [@xScale(@x_val(d)), @yScale(@y_val(d))]
                    ctx.beginPath()
                    ctx.arc(x, y, @opts.size(d), 0, Math.PI*2)
                    ctx.fill()
                    if (@opts.text?)
                        ctx.font = "12px sanserif"
                        ctx.fillText(@opts.text(d), x+2, y-2)
                    #ctx.strokeStyle="#000000"
                    #ctx.stroke()

    _draw_dots_svg: (colouring) ->
        kept  = @data.filter((d) => @opts.filter(d))
        dots = @svg.selectAll(".dot")
                   .data(kept)
        dots.exit().remove()

        # Create the dots and labels
        dot_new = dots.enter().append("g")
                                  .attr("class", "dot")

        dot_new.append("circle")
               .attr("cx",0)
               .attr("cy",0)

        # Ensure the correct size & colour
        dots.select("circle")
            .attr("r", (d) => @opts.size(d))
            .attr("opacity", (d) => @opts.alpha(d))
            .style("fill", (d,i) => colouring(d))

        if (@opts.text?)
            dot_new.append("text")
                 .attr('class',"labels")
                 .attr('x',3)
                 .attr('y',-3)
            dots.select("text")
                    .style("fill", (d,i) => colouring(d))
                    .text((d,i) => @opts.text(d))


        # And animate the moving dots
        dd = if @opts.animate then dots.transition() else dots
        dd.attr("transform", (d) => "translate(#{@xScale(@x_val(d))}, #{@yScale(@y_val(d))})")

    # Event handler for mouse-move.
    # debouce the lookup as it is potentially expensive
    _mouse_move: () ->
        loc = d3.mouse(@gDot.node())             # Location in element
        loc_doc = d3.mouse(document.body)       # Location in the page
        scheduler.schedule('scatterplot.tooltip', (() => @_handle_mouseover(loc, loc_doc)), 20)

    # Event handler for mouse-out.
    _mouse_out: () ->
        scheduler.schedule('scatterplot.tooltip', () => )
        if (@mouseover_sent)
            @mouseover_sent = false
            @dispatch.mouseout()

    # Lookup point(s) for mouseover
    # This scans all data points, so can be expensive.  It is acceptable on my machine,
    # it might be worth considering d3.geom.quadtree if it needs to be faster
    _handle_mouseover: (loc, loc_doc) ->
        [x,y] = loc

        sz=3
        # Note swapped 'y' in extent (because yScale is a -ve transform)
        ex = [[@xScale.invert(x-sz), @yScale.invert(y+sz)],
              [@xScale.invert(x+sz), @yScale.invert(y-sz)]]

        m = @_in_extent(ex)

        if (m.length>0)
            @mouseover_sent = true
            @dispatch.mouseover(m, loc, loc_doc)
        else if (@mouseover_sent)
            @mouseover_sent = false
            @dispatch.mouseout()

    _brush_empty: () ->
        @opts.brush_enable && @mybrush.empty()

    _brushed: () ->
        sel = @_selected()
        @dispatch.brush(sel, !@_brush_empty())

    # Find the data points with the extent (for brushing)
    # Extent is in screen coordina
    _in_extent: (ex) ->
        @data.filter((d) =>
            x = @x_val(d)
            y = @y_val(d)
            @opts.filter(d) && x>=ex[0][0] && x<=ex[1][0] && y>=ex[0][1] && y<=ex[1][1]
        )

    _selected: () ->
        if (@_brush_empty() || !@opts.brush_enable)
            @data.filter((d) => @opts.filter(d))
        else
            @_in_extent(@mybrush.extent())

    highlight: (rows) ->
        hi = @gHighlight.selectAll(".highlight")
                     .data(rows, (d) => d.id)
        hi.exit().remove()
        hi.enter()
          .insert("circle")
          .attr("class", "highlight")
          .attr("opacity", 1)
          .style("fill-opacity", 0)
          .style("stroke", "black")
          .style("stroke-width", 3)
        hi.attr("r", 15)
          .attr("cx", (d) => @xScale(@x_val(d)))
          .attr("cy", (d) => @yScale(@y_val(d)))
          .transition().duration(500)
          .attr("r", 7)

    unhighlight: () ->
        @svg.selectAll(".highlight").remove()

    on: (t,func) ->
        @dispatch.on(t, func)

    brush: () ->
        @_draw_dots(@colouring || @opts.colouring)
        @_brushed()

window.ScatterPlot = ScatterPlot
