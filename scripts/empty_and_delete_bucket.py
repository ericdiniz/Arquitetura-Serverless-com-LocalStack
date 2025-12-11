#!/usr/bin/env python3
"""
Empty and delete an S3 bucket (handles versioned buckets).
Usage: python3 empty_and_delete_bucket.py <bucket-name>
Requires AWS credentials via env/profile.
"""
import sys
import boto3
from botocore.exceptions import ClientError

def delete_all_objects(s3, bucket):
    paginator = s3.get_paginator("list_objects_v2")
    to_delete = []
    count = 0
    for page in paginator.paginate(Bucket=bucket):
        for obj in page.get("Contents", []):
            to_delete.append({"Key": obj["Key"]})
            if len(to_delete) == 1000:
                resp = s3.delete_objects(Bucket=bucket, Delete={"Objects": to_delete})
                count += len(to_delete)
                print(f"Deleted {count} objects so far...")
                to_delete = []
    if to_delete:
        resp = s3.delete_objects(Bucket=bucket, Delete={"Objects": to_delete})
        count += len(to_delete)
    print(f"Deleted {count} non-versioned objects (if any).")

def delete_all_versions(s3, bucket):
    paginator = s3.get_paginator("list_object_versions")
    to_delete = []
    count = 0
    any_versions = False
    for page in paginator.paginate(Bucket=bucket):
        for v in page.get("Versions", []):
            any_versions = True
            to_delete.append({"Key": v["Key"], "VersionId": v["VersionId"]})
            if len(to_delete) == 1000:
                s3.delete_objects(Bucket=bucket, Delete={"Objects": to_delete})
                count += len(to_delete)
                print(f"Deleted {count} object versions so far...")
                to_delete = []
        for dm in page.get("DeleteMarkers", []):
            any_versions = True
            to_delete.append({"Key": dm["Key"], "VersionId": dm["VersionId"]})
            if len(to_delete) == 1000:
                s3.delete_objects(Bucket=bucket, Delete={"Objects": to_delete})
                count += len(to_delete)
                print(f"Deleted {count} object versions so far...")
                to_delete = []
    if to_delete:
        s3.delete_objects(Bucket=bucket, Delete={"Objects": to_delete})
        count += len(to_delete)
    if any_versions:
        print(f"Deleted {count} versions/delete-markers.")
    else:
        print("No versions/delete-markers found (or versioning not enabled).")

def main():
    if len(sys.argv) < 2:
        print("Usage: empty_and_delete_bucket.py <bucket>")
        sys.exit(2)
    bucket = sys.argv[1]
    s3 = boto3.client("s3")
    try:
        print("Checking bucket...")
        s3.head_bucket(Bucket=bucket)
    except ClientError as e:
        print("Error accessing bucket:", e)
        sys.exit(1)

    # First remove versions (if any)
    try:
        delete_all_versions(s3, bucket)
    except ClientError as e:
        print("Error deleting versions:", e)
    # Then remove non-versioned objects (safe to run both)
    try:
        delete_all_objects(s3, bucket)
    except ClientError as e:
        print("Error deleting objects:", e)

    # Finally delete the bucket
    try:
        print("Deleting bucket:", bucket)
        s3.delete_bucket(Bucket=bucket)
        print("Bucket delete requested.")
    except ClientError as e:
        print("Error deleting bucket (maybe not empty or permission denied):", e)
        sys.exit(1)

if __name__ == "__main__":
    main()
