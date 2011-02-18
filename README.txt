Persistence
===========

A ruby library geared towards separating persistence concerns from data model classes. It includes:

- Generic repository-style persistence interfaces for a variety of data structures, from just a simple persistence Cell, to an ArrayCell, an ObjectCell, a HashRepository, to an IdentityHashRepository, which persists objects keyed by an identity property and matches the interface of many data stores.
- In-memory example implementations of these interfaces
- Database-backed implementations based on the Sequel library
   - These implement an additional interface specific to Sequel-backed persistence
   - Flexible and extensible property mapping options
   - Help wiring up repositories for multiple inter-related classes of data model

- Implementations backed by storage of serialized objects in string-based key-value cache
- Potential for more implementations backed by other persistence mechanisms
