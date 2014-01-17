$(document).ready(function() {

	loadOverview();
	setInterval(updateSummaries,10000);
	setInterval(resetOverview,10000);
} )

$.ajaxSetup ({
		cache: false
	});

function datatableAjaxRequest(url)
{
  updateSummaries();
    var dTable = $('#datatb').dataTable( {
                "fnRowCallback": fnRowCallback,
                "bProcessing": true,
                "sPaginationType": "full_numbers",
                //"bServerSide": true,
                "sAjaxSource": url,
		"aaSorting": [[ 0, "asc" ]],
                "fnServerData": function( sUrl, aoData, fnCallback ) {
                        $.ajax( {
                                "url": sUrl,
                                "data": aoData,
                                "type": "GET",
                                "crossDomain": true,
                                "dataType": "jsonp",
                                "cache": false,
				"bDestroy":true
                        } ).done( fnCallback);
                }
    } );
  /* Add event listeners to the two range filtering inputs */
    $('#min').keyup( function() { oTable.fnDraw(); } );
    $('#max').keyup( function() { oTable.fnDraw(); } );
}

function loadOverview()
{
  datatableAjaxRequest(["http://",location.host,":4567/getstatusjsonp/"].join(""));
  updateSummaries();
}
function updateSummaries()
{
  var loadUrl = ["http://",location.host,":4567/getsummaryjson/"].join("");

  $.getJSON( loadUrl, function( data ) {
    $.each( data, function( key, val ) {
      $("#summary_"+key).html(val);
    });
  });
}


function callhistory(history_name)
{
  $('#datatb').dataTable().fnDestroy();
  datatableAjaxRequest(["http://",location.host,":4567/gethistoryjsonp/?appname=",history_name].join(""));
}

function resetOverview()
{

  $('#datatb').dataTable().fnReloadAjax();
}

function fnRowCallback( nRow, aData, iDisplayIndex, iDisplayIndexFull ) {
  var buffer = [ "<a href=javascript:callhistory('",aData[0],"')>",aData[0],"</a>"];
  $('td:eq(0)', nRow).html( buffer.join("") );

  // Bold the grade for all 'A' grade browsers
  if ( aData[6] == "R" )
    {
      $(nRow).css('background-color', '#FFDDDD');
    }else if (aData[6] == "Y" )
    {
      $(nRow).css('background-color', '#FFFADB'); // YELLOW
    }else if (aData[6] == "G" )
    {
      $(nRow).css('background-color', '#DDFFDD'); // GREEN
    }else {
      $(nRow).css('background-color', '#DDDDDD'); // GRAY
    }
}



// For Reloading Table
// Credit: http://stackoverflow.com/questions/11566463/how-can-i-trigger-jquery-datatables-fnserverdata-to-update-a-table-via-ajax-when
$.fn.dataTableExt.oApi.fnReloadAjax = function (oSettings, sNewSource, fnCallback, bStandingRedraw) {
    if (typeof sNewSource != 'undefined' && sNewSource != null) {
        oSettings.sAjaxSource = sNewSource;
    }
    this.oApi._fnProcessingDisplay(oSettings, true);
    var that = this;
    var iStart = oSettings._iDisplayStart;
    var aData = [];

    this.oApi._fnServerParams(oSettings, aData);

    oSettings.fnServerData(oSettings.sAjaxSource, aData, function (json) {
        /* Clear the old information from the table */
        that.oApi._fnClearTable(oSettings);

        /* Got the data - add it to the table */
        var aData = (oSettings.sAjaxDataProp !== "") ?
            that.oApi._fnGetObjectDataFn(oSettings.sAjaxDataProp)(json) : json;

        for (var i = 0; i < aData.length; i++) {
            that.oApi._fnAddData(oSettings, aData[i]);
        }

        oSettings.aiDisplay = oSettings.aiDisplayMaster.slice();
        that.fnDraw();

        if (typeof bStandingRedraw != 'undefined' && bStandingRedraw === true) {
            oSettings._iDisplayStart = iStart;
            that.fnDraw(false);
        }

        that.oApi._fnProcessingDisplay(oSettings, false);

        /* Callback user function - for event handlers etc */
        if (typeof fnCallback == 'function' && fnCallback != null) {
            fnCallback(oSettings);
        }
    }, oSettings);
}
