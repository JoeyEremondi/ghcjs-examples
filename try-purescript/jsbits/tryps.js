/** @constructor */
function TryPs(editor, res, res_text, run_btn, run_output, run_templ) {

    this.fireBaseRef = new Firebase("https://lambda-pi-plus.firebaseio.com");
    this.userRef = null;

    this.fireBaseRef.authAnonymously( (function(error, authData) {
      if (error) {
        console.log("Login Failed!", error);
      } else {
        console.log("Authenticated successfully with payload:", authData);
        this.userRef = this.fireBaseRef.child("users").child(authData.uid);
      }
    }).bind(this) );


    this.changed = false;
    this.waiting = [];
    this.result = document.getElementById(res);
    this.result.className = "runnable";
    this.result_text = document.getElementById(res_text);
    this.run_output = document.getElementById(run_output);
    this.code = null;
    //this.prelude = document.getElementById(prelude).text;
    //this.compiledPrelude = '';
    this.run_template = document.getElementById(run_templ).text.replace(/<!--([^]*)-->/gm, "$1");
    this.editor = CodeMirror['fromTextArea'](
        document.getElementById(editor), { 'lineNumbers': true
                                         , 'mode': 'haskell'
                                         , 'theme': 'elegant'
                                         , 'tabSize': 2
                                         , 'indentWithTabs' : false
                                         });

    var that = this;
    this.editor['on']('changes', function() {
        // that.changed = true;
        // var x;
        // while(x = that.waiting.pop()) x();
    });

    //this.editor.matchBrackets();

    this.setCursorPos = function(l,c)
    {
      this.editor.focus();
      this.editor.setCursor(l-1,c-1);
    }

    document.getElementById(run_btn).addEventListener('click', function() {
        that.changed = true;
        var x;
        while(x = that.waiting.pop()) x();
        // that.result.className = "run";
        // var doc = that.run_output.contentWindow.document;
        // function addScript(c) {
        //     var s = doc.createElement('script');
        //     s.appendChild(doc.createTextNode(c));
        //     doc.getElementsByTagName('head')[0].appendChild(s);
        // }
        // doc.open();
        // doc.write(that.run_template);
        // addScript(that.compiledPrelude + that.code);
        // addScript("runPS();");
    });

  //this.getPrelude = function() {
  //    return this.prelude;
  //}

  this.waitForChange = function(c) {
      if(this.changed) c(); else this.waiting.push(c);
  }

  this.getEditorContents = function() {
      this.changed = false;
      return this.editor['getDoc']()['getValue']();
  }

  this.clearError = function() {
      this.result.className = "error";
      this.result_text.textContent = "Error output:\n\n";
  }

  this.addError = function(err) {
      this.result.className = "error";
      this.result_text.innerHTML += err;
  }

  this.addErrorAt = function(ln, col, err) {
      this.result.className = "error";
      this.result_text.innerHTML = this.result_text.innerHTML +
        '<a href="#" onclick="tryps.setCursorPos('
        + ln + "," + col + ');">  '
        + ln.toString() + "," + col.toString()
        + " </a>"
        + "&#58; "
        + err + "<br><br>";
  }

  this.reportTypeError = function(source) {
      var ourBox = document.getElementById('allowReportCheck');
      if (this.userRef && ourBox.checked)
      {
        this.userRef.push(source);
      }
  }

  // this.setCompiledPrelude = function(x) {
  //     this.compiledPrelude = x;
  // }

  this.setResult = function(res) {
      this.result.className = "runnable";
      this.result_text.textContent = res;
      this.code = res;
  }

  this.setBusy = function(msg) {
      this.result.className = "busy";
      this.result_text.textContent = msg;
  }

}



var tryps;
function trypsInit() {
    tryps = new TryPs( 'editor', 'result_outer', 'result_text', 'run_button'
                      , 'run_output', 'run_template');
}
