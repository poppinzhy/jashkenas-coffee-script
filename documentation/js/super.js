(function(){
  var Animal, Horse, Snake, __a, __b, sam, tom;
  Animal = function Animal() {
  };
  Animal.prototype.move = function move(meters) {
    return alert(this.name + " moved " + meters + "m.");
  };
  Snake = function Snake(name) {
    var __a;
    __a = this.name = name;
    return Snake === this.constructor ? this : __a;
  };
  __a = function(){};
  __a.prototype = Animal.prototype;
  Snake.__superClass__ = Animal.prototype;
  Snake.prototype = new __a();
  Snake.prototype.constructor = Snake;
  Snake.prototype.move = function move() {
    alert("Slithering...");
    return Snake.__superClass__.move.call(this, 5);
  };
  Horse = function Horse(name) {
    var __b;
    __b = this.name = name;
    return Horse === this.constructor ? this : __b;
  };
  __b = function(){};
  __b.prototype = Animal.prototype;
  Horse.__superClass__ = Animal.prototype;
  Horse.prototype = new __b();
  Horse.prototype.constructor = Horse;
  Horse.prototype.move = function move() {
    alert("Galloping...");
    return Horse.__superClass__.move.call(this, 45);
  };
  sam = new Snake("Sammy the Python");
  tom = new Horse("Tommy the Palomino");
  sam.move();
  tom.move();
})();