////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import UIKit
import RealmSwift
import ReactKit

class Entry: Object {
    dynamic var title = ""
    dynamic var date = NSDate()
}

class Group: Object {
    dynamic var name = ""
    let entries = List<Entry>()
}

class GroupParent: Object {
    let groups = List<Group>()
}

class Cell: UITableViewCell {
    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        super.init(style: .Subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    dynamic var entry: Entry?
    func attach(object: Entry) {
        if entry == nil {
            (self.textLabel!, "text") <~ KVO.stream(self, "entry.title").ownedBy(self)
            (self.detailTextLabel!, "text") <~ (KVO.stream(self, "entry.date") |> map { $0!.description }).ownedBy(self)
        }
        entry = object
    }
}

class TableViewController: UITableViewController {
    let parent: GroupParent = {
        let realm = Realm()
        let obj = realm.objects(GroupParent).first
        if obj != nil {
            return obj!
        }

        let newObj = GroupParent()
        realm.write { realm.add(newObj) }
        return newObj
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        tableView.reloadData()
    }

    // UI

    func setupUI() {
        tableView.registerClass(Cell.self, forCellReuseIdentifier: "cell")

        self.title = "GroupedTableView"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Add Group", style: .Plain, target: self, action: "addGroup")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addEntry")

        KVO.detailedStream(parent, "groups").ownedBy(self) ~> { [unowned self] _, kind, indexes in
            if let indexes = indexes where kind == .Insertion {
                self.tableView.insertSections(indexes, withRowAnimation: .Automatic)
                self.bindGroup(self.parent.groups.last!)
            }
            else {
                self.tableView.reloadData()
            }
        }

        for group in parent.groups {
            bindGroup(group)
        }
    }

    // Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return parent.groups.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return parent.groups[section].name
    }

    override func tableView(tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        return parent.groups[section].entries.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! Cell
        cell.attach(objectForIndexPath(indexPath))
        return cell
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let realm = Realm()
            realm.write {
                realm.delete(self.objectForIndexPath(indexPath))
            }
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let realm = Realm()
        realm.write {
            self.parent.groups[indexPath.section].entries[indexPath.row].date = NSDate()
        }
    }

    // Actions

    func addGroup() {
        modifyInBackground { groups in
            let group = groups.realm!.create(Group.self, value: ["name": "Group \(arc4random())", "entries": []])
            groups.append(group)
        }
    }

    func addEntry() {
        modifyInBackground { groups in
            let group = groups[Int(arc4random_uniform(UInt32(groups.count)))]
            let entry = groups.realm!.create(Entry.self, value: ["Entry \(arc4random())", NSDate()])
            group.entries.append(entry)
        }
    }

    // Helpers

    func objectForIndexPath(indexPath: NSIndexPath) -> Entry {
        return parent.groups[indexPath.section].entries[indexPath.row]
    }

    func indexSetToIndexPathArray(indexes: NSIndexSet, section: Int) -> [AnyObject] {
        var paths = [AnyObject]()
        var index = indexes.firstIndex
        while index != NSNotFound {
            paths += [NSIndexPath(forRow: index, inSection: section)]
            index = indexes.indexGreaterThanIndex(index)
        }
        return paths
    }

    func bindGroup(group: Group) {
        KVO.detailedStream(group, "entries").ownedBy(self) ~> { [unowned self] _, kind, indexes in
            if let indexes = indexes {
                let section = self.parent.groups.indexOf(group)!
                let paths = self.indexSetToIndexPathArray(indexes, section: section)
                if kind == .Insertion {
                    self.tableView.insertRowsAtIndexPaths(paths, withRowAnimation: .Automatic)
                } else if kind == .Removal {
                    self.tableView.deleteRowsAtIndexPaths(paths, withRowAnimation: .Automatic)
                } else {
                    self.tableView.reloadData()
                }
            }
            else {
                self.tableView.reloadData()
            }
        }
    }

    func modifyInBackground(block: (List<Group>) -> Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let realm = Realm()
            let parent = realm.objects(GroupParent).first!
            realm.write {
                block(parent.groups)
            }
        }
    }
}
