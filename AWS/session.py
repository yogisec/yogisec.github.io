import requests
import boto3
import botocore.exceptions
import botocore.session
import time
import sys

def main():
    try:
        while True:
            
            response = requests.get('http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance/')
            response = response.json()
            expiration = response['Expiration']
            last_update = response['LastUpdated']
            token = response['Token']
            secret = response['SecretAccessKey']
            accesskey = response['AccessKeyId']
            #s3_session = boto3.session.Session(aws_access_key_id=accesskey, aws_secret_access_key=secret, aws_session_token=token, region_name='us-east-1')
            #s3_client = s3_session.client('s3')
            s3_session = ''
            s3_session = botocore.session.get_session()
            s3_client = s3_session.create_client('s3', region_name='us-east-1')
            try:
                s3_response = s3_client.list_buckets()
                response_code = s3_response['ResponseMetadata']['HTTPStatusCode']
                # print(f'{response_code}')
                number_of_buckets = len(s3_response['Buckets'])
                print(f'AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update} -- ResponseCode: {response_code} -- NumberofBuckets: {number_of_buckets}')
            except Exception as e:
                print(f'Keys no longer valid -- AccessKeyId: {accesskey} -- Expiration: {expiration} -- LastUpdated: {last_update} -- Exception: {e}')
                pass
            time.sleep(1)
    except KeyboardInterrupt:
        print('\n Bye')
        sys.exit()

if __name__ == "__main__":
    main()