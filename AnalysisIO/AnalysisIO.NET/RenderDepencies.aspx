﻿<meta charset="utf-8">
<style>
    .node {
        font: 300 11px "Helvetica Neue", Helvetica, Arial, sans-serif;
        fill: #bbb;
    }

        .node:hover {
            fill: #000;
        }

    .link {
        stroke: steelblue;
        stroke-opacity: 0.4;
        fill: none;
        pointer-events: none;
    }

    .linkAdded {
        stroke: #2ca02c;
    }
    .linkDeleted {
        stroke: #d62728;
    }

    .node:hover,
    .node--source,
    .node--target {
        font-weight: 700;
    }

    .node--source {
        fill: #2ca02c;
    }

    .node--target {
        fill: #d62728;
    }

    .link--source,
    .link--target {
        stroke-opacity: 1;
        stroke-width: 2px;
    }

    .newClass {
        fill: #2ca02c;
    }
    .deletedClass {
        fill: #d62728;
    }

    .link--source {
        stroke: #d62728;
    }

    .link--target {
        stroke: #2ca02c;
    }
</style>
<body>
    <script src="https://d3js.org/d3.v4.min.js"></script>
    <script>

var diameter = 960,
    radius = diameter / 2,
    innerRadius = radius - 240;

var cluster = d3.cluster()
    .size([360, innerRadius]);

var line = d3.radialLine()
    .curve(d3.curveBundle.beta(0.85))
    .radius(function(d) { return d.y; })
    .angle(function(d) { return d.x / 180 * Math.PI; });

var svg = d3.select("body").append("svg")
    .attr("width", diameter)
    .attr("height", diameter)
  .append("g")
    .attr("transform", "translate(" + radius + "," + radius + ")");

var link = svg.append("g").selectAll(".link"),
    node = svg.append("g").selectAll(".node");


d3.queue().defer(d3.json, "olderTree.json").defer(d3.json, "newestTree.json").await(render);

function render(error, oldTree, newTree) {
    if (error) console.log(error);

    var newClasses=flatten(newTree);
    var oldClasses = flatten(oldTree);
    var classes = defineChanges(oldClasses, newClasses);

  var root = packageHierarchy(classes).sum(function(d) { return d.size; });

  cluster(root);
    

  link = link
    .data(packageImports(root.leaves()))
    .enter().append("path")
      .each(function (d) { d.source = d[0], d.target = d[d.length - 1]; })
      .attr("class", function (d) { return "link " + d.Changed })
      .attr("d", line);

  node = node
    .data(root.leaves())
    .enter().append("text")
      .attr("class", "node")
      .attr("dy", "0.31em")
      .attr("transform", function(d) { return "rotate(" + (d.x - 90) + ")translate(" + (d.y + 8) + ",0)" + (d.x < 180 ? "" : "rotate(180)"); })
      .attr("text-anchor", function(d) { return d.x < 180 ? "start" : "end"; })
      .text(function (d) { return d.data.key; })
      .classed("newClass", function (d) { return d.data.NewObject })
      .classed("deletedClass", function (d) { return d.data.OldObject })
      .on("mouseover", mouseovered)
      .on("mouseout", mouseouted);
}

function flatten(response) {
    return response.Children.reduce(function(flat, toFlatten) {
                return flat.concat(toFlatten.Children.length === 0 ? toFlatten : flatten(toFlatten));
            },[])
        .sort(function (a, b) { return d3.ascending(a.Identifier, b.Identifier); });
}

function defineChanges(oldClasses, newClasses) {
    //Ensure both lists contain same classes
    oldClasses = oldClasses.concat(newClasses.filter(elem => oldClasses.findIndex(item => item.Identifier === elem.Identifier) === -1)
        .map(elem => { return { Identifier: elem.Identifier, Dependencies: [], NewObject: true, Children: [] } }));
    newClasses = newClasses.concat(oldClasses.filter(elem => newClasses.findIndex(item => item.Identifier === elem.Identifier) === -1)
        .map(elem => { return { Identifier: elem.Identifier, Dependencies: [], OldObject: true, Children:[] } }));

    oldClasses = oldClasses.sort(function (a, b) { return d3.ascending(a.Identifier, b.Identifier); });
    newClasses = newClasses.sort(function (a, b) { return d3.ascending(a.Identifier, b.Identifier); });

    var classes = [];
    oldClasses.forEach((elem, index) => {
        var newElem = newClasses[index];
        if (!elem.Dependencies) {
            classes.push(newElem);
            return;
        };
        var elemsToAdd = [];
        elem.Dependencies.forEach(dep => { //look for deleted dependencies
            if (newElem.Dependencies.indexOf(dep) < 0) {
                elemsToAdd.push({ Name: dep, Change: "linkDeleted" }); //deleted
            }
        });
        var elemstoupdate = [];
        newElem.Dependencies.forEach((dep, index) => { //look for added dependencies
            if (elem.Dependencies.indexOf(dep) < 0) {
                elemstoupdate.push({Index: index, obj: { Name: dep, Change: "linkAdded" } });
            }
        });
        newElem.NewObject = elem.NewObject; //Mark object as newly added
        elemstoupdate.forEach(elem => {
            newElem.Dependencies[elem.Index] = elem.obj;
        });
        newElem.Dependencies = newElem.Dependencies.concat(elemsToAdd);
        classes.push(newElem);
    });
    return classes;
}

function mouseovered(d) {
  node
      .each(function(n) { n.target = n.source = false; });

  link
      .classed("link--target", function(l) { if (l.target === d) return l.source.source = true; })
      .classed("link--source", function(l) { if (l.source === d) return l.target.target = true; })
    .filter(function(l) { return l.target === d || l.source === d; })
      .raise();

  node
      .classed("node--target", function(n) { return n.target; })
      .classed("node--source", function(n) { return n.source; });
}

function mouseouted(d) {
  link
      .classed("link--target", false)
      .classed("link--source", false);

  node
      .classed("node--target", false)
      .classed("node--source", false);
}

// Lazily construct the package hierarchy from class names.
function packageHierarchy(classes) {
  var map = {};

  function find(Identifier, data) {
      var node = map[Identifier], i;
    if (!node) {
        node = map[Identifier] = data || { Identifier: Identifier, children: [] };
        if (Identifier.length) {
            node.parent = find(Identifier.substring(0, i = Identifier.lastIndexOf(".")));
        node.parent.children.push(node);
        node.key = Identifier.substring(i + 1);
        }
    }
    return node;
  }

  classes.forEach(function(d) {
      find(d.Identifier, d);
  });

  return d3.hierarchy(map[""]);
}

// Return a list of imports for the given array of nodes.
function packageImports(nodes) {
  var map = {},
      imports = [];

  // Compute a map from name to node.
  nodes.forEach(function(d) {
      map[d.data.Identifier] = d;
  });

  // For each import, construct a link from the source to target node.
  nodes.forEach(function(d) {
      if (d.data.Dependencies) d.data.Dependencies.forEach(function (i) {
          if (i.Name) {
              var x = map[d.data.Identifier].path(map[i.Name]);
              x.Changed = i.Change;
              imports.push(x);
          } else {
              imports.push(map[d.data.Identifier].path(map[i]));
          }
      });
  });

  return imports;
}

    </script>
    </body>