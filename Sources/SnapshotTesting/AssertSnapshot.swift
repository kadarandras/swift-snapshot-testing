import XCTest

/// Enhances failure messages with a command line diff tool expression that can be copied and pasted into a terminal.
///
///     diffTool = "ksdiff"
public var diffTool: String? = nil

/// Whether or not to record all new references.
public var record = false

/// Asserts that a given value matches a reference on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
///   - name: An optional description of the snapshot.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshot<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as snapshotting: Snapshotting<Value, Format>,
  named name: String? = nil,
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  let failure = verifySnapshot(
    matching: try value(),
    as: snapshotting,
    named: name,
    record: recording,
    timeout: timeout,
    file: file,
    testName: testName,
    line: line
  )
  guard let message = failure else { return }
  XCTFail(message, file: file, line: line)
}

/// Asserts that a given value matches references on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: An dictionnay of names and strategies for serializing, deserializing, and comparing values.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshots<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as strategies: [String: Snapshotting<Value, Format>],
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  try? strategies.forEach { name, strategy in
    assertSnapshot(
      matching: try value(),
      as: strategy,
      named: name,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

/// Asserts that a given value matches references on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: An array of strategies for serializing, deserializing, and comparing values.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshots<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as strategies: [Snapshotting<Value, Format>],
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  try? strategies.forEach { strategy in
    assertSnapshot(
      matching: try value(),
      as: strategy,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

/// Verifies that a given value matches a reference on disk.
///
/// Third party snapshot assert helpers can be built on top of this function. Simply invoke `verifySnapshot` with your own arguments, and then invoke `XCTFail` with the string returned if it is non-`nil`. For example, if you want the snapshot directory to be determined by an environment variable, you can create your own assert helper like so:
///
///     public func myAssertSnapshot<Value, Format>(
///       matching value: @autoclosure () throws -> Value,
///       as snapshotting: Snapshotting<Value, Format>,
///       named name: String? = nil,
///       record recording: Bool = false,
///       timeout: TimeInterval = 5,
///       file: StaticString = #file,
///       testName: String = #function,
///       line: UInt = #line
///       ) {
///
///         let snapshotDirectory = ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCE_DIR"]! + "/" + #file
///         let failure = verifySnapshot(
///           matching: value,
///           as: snapshotting,
///           named: name,
///           record: recording,
///           snapshotDirectory: snapshotDirectory,
///           timeout: timeout,
///           file: file,
///           testName: testName
///         )
///         guard let message = failure else { return }
///         XCTFail(message, file: file, line: line)
///     }
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
///   - name: An optional description of the snapshot.
///   - recording: Whether or not to record a new reference.
///   - snapshotDirectory: Optional directory to save snapshots. By default snapshots will be saved in a directory with the same name as the test file, and that directory will sit inside a directory `__Snapshots__` that sits next to your test file.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
/// - Returns: A failure message or, if the value matches, nil.
public func verifySnapshot<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as snapshotting: Snapshotting<Value, Format>,
  named name: String? = nil,
  record recording: Bool = false,
  snapshotDirectory: String? = nil,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  )
  -> String? {

    let recording = recording || record

    do {
      let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)
      let fileName = fileUrl.deletingPathExtension().lastPathComponent

      let snapshotDirectoryUrl = snapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? fileUrl
          .deletingLastPathComponent()
          .appendingPathComponent("__Snapshots__")
          .appendingPathComponent(fileName)

      let identifier: String
      if let name = name {
        identifier = sanitizePathComponent(name)
      } else {
        let counter = counterQueue.sync { () -> Int in
          let key = snapshotDirectoryUrl.appendingPathComponent(testName)
          counterMap[key, default: 0] += 1
          return counterMap[key]!
        }
        identifier = String(counter)
      }

      let testName = sanitizePathComponent(testName)
      let snapshotFileUrl = snapshotDirectoryUrl
        .appendingPathComponent("\(testName).\(identifier)")
        .appendingPathExtension(snapshotting.pathExtension ?? "")
      let fileManager = FileManager.default
      try fileManager.createDirectory(at: snapshotDirectoryUrl, withIntermediateDirectories: true)
      checked[snapshotDirectoryUrl, default: []].append(snapshotFileUrl)

      let tookSnapshot = XCTestExpectation(description: "Took snapshot")
      var optionalDiffable: Format?
      snapshotting.snapshot(try value()).run { b in
        optionalDiffable = b
        tookSnapshot.fulfill()
      }
      let result = XCTWaiter.wait(for: [tookSnapshot], timeout: timeout)
      switch result {
      case .completed:
        break
      case .timedOut:
        return "Exceeded timeout of \(timeout) seconds waiting for snapshot"
      case .incorrectOrder, .invertedFulfillment, .interrupted:
        return "Couldn't snapshot value"
      @unknown default:
        return "Couldn't snapshot value"
      }

      guard let diffable = optionalDiffable else {
        return "Couldn't snapshot value"
      }

      guard !recording, fileManager.fileExists(atPath: snapshotFileUrl.path) else {
        try snapshotting.diffing.toData(diffable).write(to: snapshotFileUrl)
        return recording
          ? """
            Record mode is on. Turn record mode off and re-run "\(testName)" to test against the newly-recorded snapshot.

            open "\(snapshotFileUrl.path)"

            Recorded snapshot: …
            """
          : """
            No reference was found on disk. Automatically recorded snapshot: …

            open "\(snapshotFileUrl.path)"

            Re-run "\(testName)" to test against the newly-recorded snapshot.
            """
      }

      let data = try Data(contentsOf: snapshotFileUrl)
      let reference = snapshotting.diffing.fromData(data)

      guard let (failure, attachments) = snapshotting.diffing.diff(reference, diffable) else {
        return nil
      }

      let artifactsUrl = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] ?? NSTemporaryDirectory(), isDirectory: true
      )
      let artifactsSubUrl = artifactsUrl.appendingPathComponent(fileName)
      try fileManager.createDirectory(at: artifactsSubUrl, withIntermediateDirectories: true)
      let failedSnapshotFileUrl = artifactsSubUrl.appendingPathComponent(snapshotFileUrl.lastPathComponent)
      try snapshotting.diffing.toData(diffable).write(to: failedSnapshotFileUrl)

      if !attachments.isEmpty {
        #if !os(Linux)
        if ProcessInfo.processInfo.environment.keys.contains("__XCODE_BUILT_PRODUCTS_DIR_PATHS") {
          XCTContext.runActivity(named: "Attached Failure Diff") { activity in
            attachments.forEach {
              activity.add($0)
            }
          }
        }
        #endif
      }

      let diffMessage = diffTool
        .map { "\($0) \"\(snapshotFileUrl.path)\" \"\(failedSnapshotFileUrl.path)\"" }
        ?? "@\(minus)\n\"\(snapshotFileUrl.path)\"\n@\(plus)\n\"\(failedSnapshotFileUrl.path)\""
      return """
      Snapshot does not match reference.

      \(diffMessage)

      \(failure.trimmingCharacters(in: .whitespacesAndNewlines))
      """
    } catch {
      return error.localizedDescription
    }
}


/// Asserts that all snapshots were checked for a test case
///   (call it from the test case's tearDown method)
///
/// - Parameters:
///   - for: The test case's class
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertAllSnapshotsChecked(for testClass: XCTestCase.Type, file: StaticString = #file, line: UInt = #line) {

  guard let testCount = numberOfTestMethods(testClass) else {
    XCTFail("Couldn't find methodList for \(testClass)", file: file, line: line)
    return
  }

  let fileUrl = URL(fileURLWithPath: "\(file)")
  let fileName = fileUrl.deletingPathExtension().lastPathComponent
  let directoryUrl = fileUrl.deletingLastPathComponent()
  let snapshotDirectoryUrl: URL = directoryUrl
    .appendingPathComponent("__Snapshots__")
    .appendingPathComponent(fileName)

  let counter = counterQueue.sync { () -> Int in
    checkedCounter[snapshotDirectoryUrl, default: 0] += 1
    return checkedCounter[snapshotDirectoryUrl]!
  }

  // only assert if all test were run
  guard testCount == counter else { return }

  let fileManager = FileManager.default
  do {
    let expected = try fileManager.contentsOfDirectory(
        at: snapshotDirectoryUrl, includingPropertiesForKeys: [], options: .skipsHiddenFiles)
    let diff = expected.filter { !checked[snapshotDirectoryUrl, default: []].contains($0) }
    XCTAssertEqual(diff, [], "Not all files were checked", file: file, line: line)
  } catch {
    XCTFail(error.localizedDescription, file: file, line: line)
  }
}

// MARK: - Private

private let counterQueue = DispatchQueue(label: "co.pointfree.SnapshotTesting.counter")
private var counterMap: [URL: Int] = [:]

private var checked: [URL: [URL]] = [:]
private var checkedCounter: [URL: Int] = [:]

private func numberOfTestMethods(_ testClass: XCTestCase.Type) -> Int? {
  var methodCount: UInt32 = 0
  guard let methodList = class_copyMethodList(testClass, &methodCount) else {
    return nil
  }
  let count: Int = (0..<Int(methodCount))
    .reduce(0, { result, i in
        let selName = sel_getName(method_getName(methodList[i]))
        let methodName = String(cString: selName, encoding: .utf8)!
        return result + (methodName.hasPrefix("test") ? 1 : 0)
    })
  return count
}

func sanitizePathComponent(_ string: String) -> String {
  return string
    .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}
