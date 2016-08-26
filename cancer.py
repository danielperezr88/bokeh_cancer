from bokeh.plotting import curdoc, figure
from bokeh.layouts import gridplot
from bokeh.models.widgets import Slider
from bokeh.models.callbacks import CustomJS
from bokeh.models import ColumnDataSource, WidgetBox, Div, Column, Spacer

import requests as req

from string import Template
from addjquery import AddJQuery

DIV_TEMPLATE = Template("\n".join([
    "<div class=\"outer\" style=\"display:table; position:absolute; height:100%; width:100%;\">",
    "   <div class=\"middle\" style=\"display:table-cell; vertical-align:middle;\">",
    "       <div class=\"inner\" id=\"results-container\" style=\"width:100%;text-align:center;margin-right:auto;margin-left:auto;\">",
    "           ${content}",
    "       </div>",
    "   </div>",
    "</div>"
]))

default_data = req.post(url="http://127.0.0.1:50002/defaults", timeout=20).json()
static_source = ColumnDataSource(data=default_data['results'])

callback = CustomJS(args=dict(ss=static_source), code="""

    var inputs = $('div .bk-slider-parent').find('input');
    inputs = $.map(inputs, function(a){return $(a).val()});

    function update_plot(data){
        ss.data = data['results'];
        ss.trigger('change');
    }

    function update_text(data){
        $('#results-container').html(data['results']);
    }

    clearTimeout(timer)
    timer = window.setTimeout(function(){
        $.ajax({
            url: 'http://localhost:50002/compute/[' + inputs + ']',
            type: 'POST',
            contentType: 'application/json',
            success: update_plot
        });

        $.ajax({
            url: 'http://localhost:50002/predict/[' + inputs + ']',
            type: 'POST',
            contentType: 'application/json',
            success: update_text
        });
    }, 2000);

""")


def redraw():
    static_source.data = default_data['results']


field_data = req.post(url="http://127.0.0.1:50002/fields", timeout=20).json()
sliders = WidgetBox(
    children=list(Slider(**dict(zip(list(f.keys())+['callback'],list(f.values())+[callback]))) for f in field_data['results']),
    width=30
)

#scatter = Scatter3d(x='x', y='y', z='z', color='color', data_source=static_source)
plot = figure(title='PCA Plot', plot_height=300, plot_width=400, responsive=True, tools="pan,reset,save,wheel_zoom")
plot.scatter(x='x', y='y', color='color', source=static_source)

def_cont = req.post(url="http://127.0.0.1:50002/predict/default", timeout=20).json()

text = Column(children=[
    plot,
    Div(text=DIV_TEMPLATE.substitute(**dict(content=def_cont['results'])), sizing_mode='scale_both')
], width=65)
spacer = Spacer(width=5)

curdoc().add_root(gridplot([[text, spacer, sliders]], responsive=True))
#curdoc().add_root(gridplot([[script, plot, sliders]], responsive=True))

curdoc().add_next_tick_callback(redraw)
