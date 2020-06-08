package ui.modal;

class EditLayerDefs extends ui.Modal {
	var jList : js.jquery.JQuery;
	var jForm : js.jquery.JQuery;
	public var cur : Null<LayerDef>;

	public function new() {
		super();

		loadTemplate( hxd.Res.tpl.editLayerDefs, "defEditor layerDefs" );
		jList = jWin.find(".mainList ul");
		jForm = jWin.find("ul.form");

		// Create layer
		jWin.find(".mainList button.create").click( function(_) {
			var ld = project.createLayerDef(IntGrid);
			select(ld);
			client.ge.emit(LayerDefChanged);
			jForm.find("input").first().focus().select();
		});

		// Delete layer
		jWin.find(".mainList button.delete").click( function(ev) {
			if( project.layerDefs.length==1 ) {
				N.error("Cannot delete the last layer.");
				return;
			}

			new ui.dialog.Confirm(ev.getThis(), "If you delete this layer, it will be deleted in all levels as well. Are you sure?", function() {
				project.removeLayerDef(cur);
				select(project.layerDefs[0]);
				client.ge.emit(LayerDefChanged);
			});
		});


		select(client.curLayerContent.def);
	}

	override function onGlobalEvent(e:GlobalEvent) {
		super.onGlobalEvent(e);
		switch e {
			case ProjectChanged: close();

			case LayerDefChanged:
				updateForm();
				updateList();

			case LayerDefSorted:
				updateList();

			case LayerContentChanged:

			case EntityDefChanged:
			case EntityDefSorted:
			case EntityFieldChanged:
		}
	}

	function select(ld:LayerDef) {
		cur = ld;

		jForm.find("*").off(); // cleanup event listeners

		// Set form class
		for(k in Type.getEnumConstructs(LayerType))
			jForm.removeClass("type-"+k);
		jForm.addClass("type-"+ld.type);

		// Fields
		var i = Input.linkToHtmlInput( ld.name, jForm.find("input[name='name']") );
		i.validityCheck = project.isLayerNameValid;
		i.onChange = client.ge.emit.bind(LayerDefChanged);

		var i = Input.linkToHtmlInput( ld.type, jForm.find("select[name='type']") );
		i.onChange = client.ge.emit.bind(LayerDefChanged);

		var i = Input.linkToHtmlInput( ld.gridSize, jForm.find("input[name='gridSize']") );
		i.setBounds(1,32);
		i.onChange = client.ge.emit.bind(LayerDefChanged);

		var i = Input.linkToHtmlInput( ld.displayOpacity, jForm.find("input[name='displayOpacity']") );
		i.displayAsPct = true;
		i.setBounds(0.1, 1);
		i.onChange = client.ge.emit.bind(LayerDefChanged);

		// Layer-type specific inits
		switch ld.type {

			case IntGrid:
				var valuesList = jForm.find("ul.intGridValues");
				valuesList.find("li.value").remove();

				// Add intGrid value button
				var addButton = valuesList.find("li.add");
				addButton.find("button").off().click( function(ev) {
					ld.addIntGridValue(0xff0000);
					client.ge.emit(LayerDefChanged);
					updateForm();
				});

				// Existing values
				var idx = 0;
				for( intGridVal in ld.getAllIntGridValues() ) {
					var curIdx = idx;
					var e = jForm.find("xml#intGridValue").clone().children().wrapAll("<li/>").parent();
					e.addClass("value");
					e.insertBefore(addButton);
					e.find(".id").html("#"+idx);

					// Edit value name
					var i = new Input(
						e.find("input.name"),
						function() return intGridVal.name,
						function(v) intGridVal.name = v
					);
					i.validityCheck = ld.isIntGridValueNameValid;
					i.validityError = N.error.bind("This value name is already used.");
					i.onChange = client.ge.emit.bind(LayerDefChanged);

					if( ld.countIntGridValues()>1 && idx==ld.countIntGridValues()-1 )
						e.addClass("removable");

					// Edit color
					var col = e.find("input[type=color]");
					col.val( C.intToHex(intGridVal.color) );
					col.change( function(ev) {
						ld.getIntGridValueDef(curIdx).color = C.hexToInt( col.val() );
						client.ge.emit(LayerDefChanged);
						updateForm();
					});

					// Remove
					e.find("a.remove").click( function(ev) {
						function run() {
							ld.getAllIntGridValues().splice(curIdx,1);
							client.ge.emit(LayerDefChanged);
							updateForm();
						}
						if( ld.isIntGridValueUsedInProject(project, curIdx) ) {
							new ui.dialog.Confirm(e.find("a.remove"), L.t._("This value is used in some levels: removing it will also remove the value from all these levels. Are you sure?"), run);
							return;
						}
						else
							run();
					});
					idx++;
				}


			case Entities:
				// TODO
		}

		updateList();
	}


	function updateForm() {
		select(cur);
	}


	function updateList() {
		jList.empty();

		for(ld in project.layerDefs) {
			var e = new J("<li/>");
			jList.append(e);

			var icon = new J('<div class="icon"/>');
			e.append(icon);
			switch ld.type {
				case IntGrid: icon.addClass("intGrid");
				case Entities: icon.addClass("entity");
			}

			e.append('<span class="name">'+ld.name+'</span>');
			if( cur==ld )
				e.addClass("active");

			e.click( function(_) select(ld) );
		}

		// Make layer list sortable
		JsTools.makeSortable(".window .mainList ul", function(from, to) {
			var moved = project.sortLayerDef(from,to);
			select(moved);
			client.ge.emit(LayerDefSorted);
		});
	}
}